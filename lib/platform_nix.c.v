module vtk

import term.termios
import time

#include <unistd.h>
#include <poll.h>
#include <fcntl.h>
#include "@VMODROOT/lib/tty_signal.h"
#include <sys/ioctl.h>

struct C.pollfd {
	fd      int
	events  i16
	revents i16
}

struct C.winsize {
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

fn C.poll(voidptr, u32, int) int
fn C.ioctl(int, u64, ...voidptr) int
fn C.ttyname(int) &char
fn C.tcflush(int, int) int
fn C.tcgetpgrp(int) int
fn C.getpgrp() int
fn C.raise(int) int
fn C.vtk_tty_install_signals(int) bool
fn C.vtk_tty_restore_signals()
fn C.vtk_tty_take_signal() int

struct TtyOutput {
	text string
	discard_on_stop bool
}

@[heap]
struct Driver {
mut:
	saved        termios.Termios
	active       bool
	mouse_motion bool
	conservative bool
	pointer      MousePointer
	eof          bool
	interrupted  bool
	resumed      bool
	read_buffer  []u8
	wake         [2]i32
	polls        []C.pollfd
	write_fd     int = -1
	output_queue []TtyOutput
	output_head  int
	output_at    int
	resized      bool
	terminals_ready bool
	terminal_check_at i64
}

fn tty_in_foreground() bool {
	foreground := C.tcgetpgrp(0)
	return foreground < 0 || foreground == C.getpgrp()
}

fn (mut d Driver) start_platform() ! {
	if C.isatty(0) == 0 || C.isatty(1) == 0 { return error('vtk needs an interactive terminal') }
	if !tty_in_foreground() { return error('vtk needs the foreground terminal') }
	if termios.tcgetattr(0, mut d.saved) != 0 { return error('cannot read terminal attributes') }
	mut raw := d.saved
	raw.c_iflag &= termios.invert(termios.flag(int(C.BRKINT) | int(C.ICRNL) | int(C.INPCK) | int(C.ISTRIP) | int(C.IXON)))
	raw.c_lflag &= termios.invert(termios.flag(int(C.ECHO) | int(C.ICANON) | int(C.IEXTEN) | int(C.ISIG)))
	raw.c_cflag |= termios.flag(C.CS8)
	raw.c_cc[C.VMIN] = 0
	raw.c_cc[C.VTIME] = 0
	d.open_wake_pipe()
	if !C.vtk_tty_install_signals(d.wake[1]) {
		d.close_wake_pipe()
		return error('cannot install terminal signal handlers')
	}
	for {
		if termios.tcsetattr(0, C.TCSAFLUSH, mut raw) == 0 { break }
		if C.errno != C.EINTR {
			C.vtk_tty_restore_signals()
			d.close_wake_pipe()
			return error('cannot set terminal raw mode')
		}
	}
	// Open the tty independently so changing its file flags does not change
	// stdin, stdout or the caller's file descriptions.
	name := C.ttyname(1)
	if !isnil(name) {
		for {
			d.write_fd = C.open(name, C.O_WRONLY | C.O_NOCTTY | C.O_NONBLOCK | C.O_CLOEXEC, 0)
			if d.write_fd >= 0 || C.errno != C.EINTR { break }
		}
	}
}

fn (mut d Driver) stop_platform() {
	d.finish_output()
	if d.write_fd >= 0 {
		C.close(d.write_fd)
		d.write_fd = -1
	}
	d.output_queue, d.output_head, d.output_at = [], 0, 0
	// Restore even when the tty stopped accepting output. Then discard any reports
	// still in the input queue, including bytes pending the switch back to canonical mode.
	for {
		if termios.tcsetattr(0, C.TCSANOW, mut d.saved) == 0 || C.errno != C.EINTR { break }
	}
	for {
		if C.tcflush(0, C.TCIFLUSH) == 0 || C.errno != C.EINTR { break }
	}
	d.read_buffer = []
	C.vtk_tty_restore_signals()
	d.close_wake_pipe()
	d.polls = []
}

fn (mut d Driver) suspend() {
	d.stop()
	if C.vtk_tty_take_signal() == C.SIGTERM {
		d.eof = true
		return
	}
	C.raise(C.SIGTSTP)
	// A background continuation must leave the shell in control of the tty.
	for !tty_in_foreground() { C.raise(C.SIGSTOP) }
	d.start() or {
		d.eof = true
		return
	}
	d.resumed = true
	d.resized = true
}

fn (mut d Driver) read(timeout int, terminals []&Ctl) string {
	d.polls.clear()
	d.polls << C.pollfd{fd: 0, events: i16(C.POLLIN)}
	d.polls << C.pollfd{fd: d.wake[0], events: i16(C.POLLIN)}
	d.polls << C.pollfd{fd: if d.output_busy() { d.write_fd } else { -1 }, events: i16(C.POLLOUT)}
	d.terminals_ready = false
	mut wait := if d.wake[0] < 0 { limit_wait(timeout, 100) } else { timeout }
	mut has_terminals := false
	for c in terminals {
		term := c.term or { continue }
		if c.closed || term.pty.fd < 0 { continue }
		has_terminals = true
		if term.pty.drained { continue }
		flags := C.POLLIN | if term.pending != '' { C.POLLOUT } else { 0 }
		d.polls << C.pollfd{fd: term.pty.fd, events: i16(flags)}
	}
	// The shell can exit without a hangup if another process holds the slave open.
	if has_terminals { wait = limit_wait(wait, d.terminal_check_at - time.ticks()) }
	if C.poll(d.polls.data, u32(d.polls.len), wait) < 0 && C.errno != C.EINTR {
		d.eof = true
		return ''
	}
	if has_terminals {
		now := time.ticks()
		if now >= d.terminal_check_at {
			d.terminal_check_at = now + 100
			d.terminals_ready = true
		}
	}
	if d.polls[1].revents != 0 {
		mut signals := [32]u8{}
		C.read(d.wake[0], &signals[0], signals.len)
		d.resized = true
	}
	signal := C.vtk_tty_take_signal()
	if signal != 0 {
		match signal {
			C.SIGINT { d.interrupted = true }
			C.SIGTSTP { d.suspend() }
			else { d.eof = true }
		}
		return ''
	}
	if d.polls[2].revents != 0 { d.flush_output() }
	for p in d.polls[3..] {
		if p.revents != 0 { d.terminals_ready = true; break }
	}
	events := d.polls[0].revents
	if events == 0 { return '' }
	if d.read_buffer.len == 0 { d.read_buffer = []u8{len: 16384} }
	n := int(C.read(0, d.read_buffer.data, uint(d.read_buffer.len)))
	if n <= 0 {
		// VMIN=0 also allows a zero-byte read when a readable indication goes stale.
		if events & i16(C.POLLHUP | C.POLLERR | C.POLLNVAL) != 0
			|| (n < 0 && C.errno !in [C.EINTR, C.EAGAIN, C.EWOULDBLOCK]) { d.eof = true }
		return ''
	}
	return d.read_buffer[..n].bytestr()
}

fn (mut d Driver) open_wake_pipe() {
	d.wake = [-1, -1]!
	if C.pipe(&d.wake[0]) != 0 { return }
	for fd in d.wake {
		if C.fcntl(fd, C.F_SETFL, C.O_NONBLOCK) < 0 || C.fcntl(fd, C.F_SETFD, C.FD_CLOEXEC) < 0 {
			d.close_wake_pipe()
			return
		}
	}
}

fn (mut d Driver) close_wake_pipe() {
	for fd in [d.wake[1], d.wake[0]] {
		if fd >= 0 { C.close(fd) }
	}
	d.wake = [-1, -1]!
}

fn (mut d Driver) resize_pending() bool {
	pending := d.resized || d.wake[0] < 0
	d.resized = false
	return pending
}

fn (d &Driver) size() (int, int) {
	mut ws := C.winsize{}
	if C.ioctl(1, u64(C.TIOCGWINSZ), &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0 {
		return int(ws.ws_col), int(ws.ws_row)
	}
	return 80, 24
}

fn (d &Driver) output_busy() bool { return d.output_queue.len > 0 }

fn (mut d Driver) output(sequence string, options TtyWriteOptions) {
	if sequence == '' { return }
	if d.write_fd < 0 {
		print(sequence)
		flush_stdout()
		return
	}
	d.output_queue << TtyOutput{sequence, options.discard_on_stop}
	d.flush_output()
}

fn (mut d Driver) flush_output() {
	for d.output_head < d.output_queue.len {
		chunk := d.output_queue[d.output_head].text
		remaining := &chunk[d.output_at..]
		count := int(C.write(d.write_fd, remaining.str, uint(remaining.len)))
		if count < 0 && C.errno == C.EINTR { continue }
		if count < 0 && (C.errno == C.EAGAIN || C.errno == C.EWOULDBLOCK) { return }
		if count <= 0 {
			d.eof = true
			d.output_queue, d.output_head, d.output_at = [], 0, 0
			return
		}
		d.output_at += count
		if d.output_at == chunk.len {
			d.output_queue[d.output_head] = TtyOutput{}
			d.output_head++
			d.output_at = 0
		}
	}
	d.output_queue.clear()
	d.output_head = 0
}

fn (mut d Driver) discard_output() {
	if !d.output_busy() { return }
	mut pending := []TtyOutput{}
	for i in d.output_head .. d.output_queue.len {
		chunk := d.output_queue[i]
		if !chunk.discard_on_stop {
			pending << chunk
		} else if i == d.output_head && d.output_at > 0 {
			// Cancel an incomplete CSI/OSC before writing the restore sequences.
			// A cut-off ANSI frame may also have left the scroll region set.
			pending << TtyOutput{text: d.cancel_output()}
			d.output_at = 0
		}
	}
	d.output_queue = pending
	d.output_head = 0
}

fn (d &Driver) cancel_output() string {
	return if d.conservative { '\x18' } else { '\x18\x1b[r' }
}

fn (mut d Driver) finish_output() {
	d.discard_output()
	d.output(tty_restore(d.conservative, d.pointer.restore()))
	deadline := time.ticks() + 500
	for d.output_busy() {
		wait := limit_wait(-1, deadline - time.ticks())
		if wait == 0 { break }
		mut p := C.pollfd{fd: d.write_fd, events: i16(C.POLLOUT)}
		result := C.poll(&p, 1, wait)
		if result < 0 && C.errno == C.EINTR { continue }
		if result <= 0 || p.revents & i16(C.POLLERR | C.POLLHUP | C.POLLNVAL) != 0 { break }
		d.flush_output()
	}
	// A stalled reader can leave the kernel's own queue full of stale paint.
	// Retry the outstanding cleanup after dropping that backlog. The final
	// pointer pop is last, so a partly written restore can be retried safely.
	if d.output_busy() {
		for {
			if C.tcflush(d.write_fd, C.TCOFLUSH) == 0 {
				d.output_queue[d.output_head] = TtyOutput{text: d.cancel_output() + d.output_queue[d.output_head].text}
				d.output_at = 0
				d.flush_output()
				break
			}
			if C.errno != C.EINTR { break }
		}
	}
}
