# Rendering, input and embedded terminals

## Terminal presenters

Set `app.rendering` before calling `init()` or `run()`.

```v
mut app := vtk.new_app()
app.rendering = vtk.RenderOptions{
    backend: .ansi
    slow_terminal: true
}
```

- `.ansi` is the default. It sends changed cells and uses VT scrolling when
  a full-width region consists of exact shifted rows.
- `.conservative` uses basic colors and avoids scroll-region operations and
  cursor shape requests. It still requires a VT-compatible terminal.
- `.memory` needs no terminal. Call `dispatch` and `step(0)` to drive the app,
  then read `snapshot()`. It uses the same layout and widget painting as ANSI.

For apps using the default options, set `VTK_RENDERER=conservative` or
`VTK_SLOW_TERMINAL=1` in the environment.

The slow terminal profile uses ASCII and basic colors, limits frames to about
12 per second, slows spinners, and suppresses passive mouse reports unless a
software cursor is enabled. On Unix, pending output is drained as the tty
becomes writable. The event loop can continue handling input and coalesce new
damage meanwhile. On shutdown, terminal cleanup takes priority over queued
frames and clears any input reports still buffered in the tty. On Unix,
`SIGTSTP` releases the terminal, and foreground resume reopens it
and redraws the screen. The Windows console uses its native synchronous output
and a bounded wait for size changes and embedded terminal output.

## Headless previews and tests

Compile an app with `-d vtk_snapshot` to render its first frame to stdout
and exit. If it opens a modal at startup, the preview shows that dialog.
Run these from a checkout of VTK.

```sh
v -d vtk_snapshot run app/calc.v
mkdir -p build
v -d vtk_snapshot -o build/spreadsheet-preview run app/spread.v --chart
```

Use the memory presenter in tests to drive input and assert screen contents.
`step(0)` processes pending work without waiting.

```v
import vtk

fn main() {
	mut app := vtk.new_app()
	app.rendering = vtk.RenderOptions{backend: .memory}
	mut window := app.window('Preview', 40, 10)
	mut field := vtk.entry('', 0)
	window.add(mut field)
	app.init() or { panic(err) }
	defer { app.fini() }
	app.layout()
	app.set_focus(field)
	app.dispatch(vtk.Event{kind: .paste, text: 'Headless input'})
	app.step(0)
	assert app.snapshot().contains('Headless input')
}
```

## Custom drawing

Use `ctl.invalidate_paint()` or `app.invalidate_area(rect)` when layout is
unchanged. VTK batches and recomposes the touched rows, including overlapping
windows and both cells of wide characters. Use `invalidate()` for geometry,
widget tree, or broad application changes. A custom mouse callback that returns
false can explicitly invalidate any changes it made.

Create a canvas with `vtk.canvas(width, height, paint)` and attach it to a
window or container. The painter receives the control and a clipped screen.
`Screen` offers text, fill, frame, and line primitives in absolute cell
coordinates. Use the canvas's `content_rect()` to offset local positions.

```v
fn paint_status(mut canvas vtk.Ctl, mut screen vtk.Screen) {
	area := canvas.content_rect()
	screen.text(area.x, area.y, 'Ready', vtk.bright_white, vtk.blue, vtk.bold)
}
```

Use `screen.set_cursor(x, y, shape)` to place a caret within the clip rectangle.
`app.overlay` is an optional `fn (mut vtk.App, mut vtk.Screen)` painter that runs
after windows, notices and popups. Use it for floating feedback such as drag
previews. It follows partial repaint clipping, so invalidate the old and new
areas when an overlay moves. `app.redraw()` and `app.snapshot()` can also render
and inspect a frame in memory without opening a terminal.

VTK measures terminal widths per Unicode grapheme, including emoji with
presentation selectors, skin tones, flags, and ZWJ sequences. Drawing,
alignment, wrapping, and hit testing use the same widths. The terminal parser
also joins sequences delivered across separate PTY reads. To regenerate
[`lib/emoji_data.v`](../lib/emoji_data.v), use
[`tools/unicode-width.swift`](../tools/unicode-width.swift).

## Mouse cursor and hover

VTK requests xterm any-event mouse tracking (1003) with SGR coordinates (1006),
so compatible terminals report movement even when no button is held. Hover
tracking is enabled by default. An optional software cursor follows the mouse
independently of the keyboard caret.

```v
app.set_mouse_cursor(vtk.MouseCursor{
    enabled: true
    glyph: `█`
    fg: vtk.bright_white
    bg: vtk.black
})
button.mouse_enter = on_hover
button.mouse_leave = on_hover
```

Both callbacks have the usual `fn (mut vtk.Ctl, mut vtk.App)` signature.
`control.is_hovered()` is already updated when they run. Enter and leave fire once
per transition on the deepest eligible control, without bubbling to parents
or changing keyboard focus. For movement without a button held, `mousefn`
receives `motion == true`, `button == .none`, and `pressed == false`.
`app.hovered_ctl()` returns the hovered control or `none`. `app.mouse_position()`
returns zero-based terminal cells, or `(-1, -1)` when the position is unknown.

Set `control.mouse_capture = true` on controls that draw their own drags.
After its `mousefn` consumes a left press, the control keeps receiving motion
and the release until the button goes up, even outside its rectangle. Focused
controls also receive bracketed paste through `keyfn` as an `Event` with
`kind == .paste`. Return true to consume the text.

The cursor supports a single-cell glyph, foreground and background colors,
and `attr`. `set_mouse_cursor` returns false for a wide, combining, or control glyph.
ASCII themes translate its glyph using the normal fallback. Disable it with
`app.set_mouse_cursor(vtk.MouseCursor{})`. `app.set_mouse_motion(false)` restores
button/drag-only reporting when the software cursor is disabled. These settings
can change while the app runs. In Settings, **Block mouse cursor** controls
visibility. **Apply** previews the change, **Save** persists it, and **Reset**
disables it.
The widgets demo shows the block cursor and hover feedback in its status bar.

`MouseCursor.hide_pointer` defaults to true. VTK asks the terminal whether
OSC 22 supports a `none` pointer shape. After an affirmative reply, it hides
the desktop pointer while the block cursor is visible. Disabling the block
cursor, losing terminal focus, moving outside the viewport or exiting VTK
restores the previous pointer shape with OSC 22 push/pop. Set
`hide_pointer: false` to keep the desktop pointer. Use
`app.mouse_pointer_supported()` to check the detected capability. Detection
runs asynchronously.

Hover respects clipping, window stacking, modality and overlays, and is
rechecked after layout changes. Closing, minimizing or destroying a hovered
control clears its hover state. Terminal focus loss clears hover and hides
the pointer until the next mouse report. Coordinates are limited to cells
inside the terminal. Idle movement and hover require terminal motion reports.
Leaving the terminal while it retains focus can leave the last pointer
position visible because the protocol has no portable pointer-exit event.

## Embedded terminals

The terminal control uses a Unix PTY or Windows ConPTY. Its xterm subset
supports cursor movement, erasing, insert/delete, scroll regions, SGR,
16/256/RGB colors, and UTF-8. VTK polls output in bounded batches and
releases the child process and PTY when the window closes.

Applications can request X10, normal, button-motion or any-motion mouse
tracking (modes 9, 1000, 1002 and 1003), with legacy or SGR (1006) reports.
Clicks, drags and wheel events use coordinates relative to the terminal's
content area. When tracking is disabled, wheel events follow normal widget
scrolling behavior.

Use `app.terminal_window()` for a standalone shell window, or create a
control with `vtk.terminal(cols, rows, options)` and attach it to a layout.
Both constructors return errors on startup failure. Pass a directory and
title when opening a shell for a specific workspace.

```v
mut window := app.terminal_window(
	directory: '/path/to/worktree'
	title: 'Shell: feature-worktree'
)!
window.set_text('Shell: renamed')
```

`app.terminal_window()` inherits the application's
current directory and uses `Terminal` as the title. The directory is applied to
the child process without changing the application's working directory. Relative
paths resolve against the application's current directory. VTK passes paths
directly to the OS, so spaces and quotes need no shell escaping. Directory and
shell startup failures return an error before creating a window. Embedded
controls can also set the directory with `vtk.terminal(72, 18, directory: worktree)!`.

When its shell exits, a standalone terminal window adds `[exited]` to its title
and requests a normal window close. Set `keep_open: true` to keep the window and
its final output visible. A window's `closing` callback can also veto the close.
Embedded terminals leave their containing window open.

Both constructors accept an `on_exit` callback with the signature
`fn (mut Ctl, mut App)`. The event loop calls it once after detecting child exit,
reading available output and releasing the PTY. The callback runs before the
automatic window close. Get the terminal state with `control.terminal_state()`
and check `has_exited()` on that state. Explicit terminal and window cleanup
skip the callback.

Try `v run examples/terminal.v /path/to/worktree 'Shell: feature-worktree'`.
