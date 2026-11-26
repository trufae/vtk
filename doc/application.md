# App, windows and dialogs

`vtk.App` manages windows, focus, the desktop, the clipboard and the event
loop. Use `app.run()!` for a standalone app. For a loop you control, call
`app.init()!` once, `app.step(timeout_ms)` to process events and paint, and
`app.fini()` for cleanup. Use `app.dispatch(event)` to feed a VTK event
directly. See the [headless example](terminal.md#headless-previews-and-tests).

## Window management

Create a window with `app.window(title, width, height)`. Window dimensions
and positions are measured in terminal cells. Use `app.raise(mut window)`
to bring one forward, `app.move(mut window, x, y)` to reposition it, and
`window.set_size_limits(min_w, min_h, max_w, max_h)` to constrain resizing.
`app.minimize`, `app.maximize`, `app.restore`, and `app.always_on_top` act
on individual windows. `app.tile()` and `app.cascade()` arrange the workspace.

Windows drag by their title, resize from the frame and support minimize,
maximize, restore, tile, cascade, size limits and always-on-top ordering.
Double-click a title to maximize the window. Double-click again to restore it.
Drag a maximized window's frame edge or corner to resize it from its current bounds.
The minimum window size is 16 columns by 3 rows, including the frame.
Opening, moving, resizing and arranging windows keep their full frames inside
the workspace, respecting their size limits and the app bar at either edge.
Changing the bar's position or visibility moves windows back inside the workspace.
Terminal resizing preserves screen-edge attachments and touching window borders,
including manually arranged tiles. Shared borders follow the workspace proportions.
Windows attached along only one edge retain their size where space permits.
Unattached axes preserve the proportional gaps to opposite workspace edges without
resizing the window, so centered windows stay centered. Window size limits take
precedence, and windows are clamped to fit when space is limited.
Repeated resizes retain the original layout without rounding drift, even
after a terminal temporarily becomes too small to contain the minimum sizes.
Set `window.controls` to a bitmask of `vtk.window_menu`, `vtk.window_minimize`,
`vtk.window_maximize`, and `vtk.window_close` to choose the title buttons.
On the app bar's `[= AppName]` button, click `=` for the window actions menu
or click its name to raise and restore the window.
Buttons keep their creation order when windows are raised, minimized or pinned.

## Keyboard shortcuts

Tab and Shift-Tab cycle focus. Ctrl-Tab and Ctrl-Shift-Tab cycle windows.
F10 or Alt-M opens the window menubar. Ctrl-G opens the system menu and
Alt-S / Alt-F10 opens Start (Alt-A still works). Ctrl-O opens Start when the focused control does
not handle it. Menus also accept h/j/k/l. Escape closes dismissable windows.
Alt-F7 and Alt-F8 start keyboard Move and Resize. Arrow keys move one cell
and Shift-arrows move five cells. Enter accepts the new rectangle, and
Escape restores the original.
`parse_binding` and `app.set_keys` configure these shortcuts atomically.

## Desktop launchers and notifications

`app.register(name, callback)` adds a launcher to **Start** and keeps the
event loop running after the last window closes. The callback has signature
`fn (mut vtk.App)` and can capture launcher state. Set `app.start_programs = true`
to group launchers under **Programs**. `app.notify(text, timeout_ms)` posts
a dismissible notification. A zero timeout keeps it visible until closed.
`app.after(ms, callback)` and `app.every(ms, callback)` run one-shot and
repeating callbacks on the event-loop thread. Save the returned ID for
`app.cancel_hook(id)`.

## Dialogs

Pass a window as `owner` to make a dialog modal to that window. Pass `none` to
block input across the app while the dialog is open. Built-in dialogs run a
nested event loop until dismissed.

| Call on `app` | Result |
| --- | --- |
| `msgbox_for(owner, title, text)` | Message with an OK button. |
| `confirm_for(owner, title, text)` | `true` on confirmation. |
| `prompt_for(owner, title, text, initial)` | Entered text as `?string`. |
| `choice_for(owner, title, items, columns)` | Zero-based index, or `-1` on cancellation. |
| `list_choice_for(owner, title, items, selected)` | Zero-based index, or `-1` on cancellation. |
| `file_pick_for(owner, directory)` | Path as `?string`. The working directory stays the same. |
| `color_pick(owner, title, rgb)`, `emoji_pick(owner)` | Optional color or emoji. |
| `date_pick(owner, title, initial)` | Selected date as `?time.Time`. |
| `history_for(owner, mut editor)` | An editor's undo history dialog. |

```v
fn ask_name(mut button vtk.Ctl, mut app vtk.App) {
	if name := app.prompt_for(button.owner_window(), 'Profile', 'Your name', '') {
		app.notify('Hello, ${name}!', 2000)
	}
}
```

`app.prompt` and `app.msgbox` use the top window as owner. `app.confirm_quit()`
prompts before requesting quit. Settings is application-modal.

For a custom dialog, build a control subtree and pass it to
`app.dialog(title, mut body)`. Register a default button with
`app.set_default_button(mut dialog, button)` and call
`app.modal_for(mut dialog, owner)` to run the dialog and read its
`dialog_result`. A button callback can set that value and close the dialog.

## Settings and themes

Settings use **`~/vtk.ini`**, with a `[vtk]` section. Call
`app.settings_file(path)` before initialization to override the location.
Physical terminal initialization loads the settings when `app.desktop` is
enabled. Use `app.settings_load()!`, `app.settings_save()!`, or
`app.settings_reset()!` to manage them explicitly.

By default, the `[Start]` bar uses the bottom line. **Window bar at top**,
`app.bar_top`, or `bar_top = 1` in the INI file places it on the first line
and opens its menus downward.
Settings include a desktop background color picker with live color swatches and
optional window title gradients. Active and inactive titles have separate gradient
colors. **Apply** previews changes and **Save** keeps them for future sessions.
**macOS window buttons** places Close, the window menu (`[=]`), and Minimize
on the left, in that order. Set `app.macos_buttons` or
`macos_buttons = 1` in the INI file for the same layout. **Reset** restores
the defaults.
Settings persist theme colors, the bar position, visibility and clock,
shadows, inactive dimming, mouse cursor visibility, Vim mode, and move/resize
bindings. Theme presets are Borland, Light Borland, Dark, Light, Teal, Modern,
Serial and `wineight`. Selecting `wineight` enables title gradients and uses a
Windows 98-style RGB palette with a teal desktop, silver controls, white
fields, navy selections, and blue active titles. Inactive titles fade from
gray to silver.
`app.theme` can be edited directly. Window titlebars use `title`, `title_bg` and
`title_bg_end`. Dimmed inactive titles use `inactive_title`, `inactive_title_bg`
and `inactive_title_bg_end`. Gradients span the title and its window buttons.
Focused controls use the `focus_fg` and `focus_bg` pair. Dark and Modern use
RGB palettes for consistent contrast across terminal color schemes.
`color_rgb` and `color_256` provide extended colors.
Serial uses basic ANSI colors and ASCII fallbacks when gradients are off.

## Virtual desktops

The appbar starts with **Start** and a slot for each configured virtual desktop.
The active slot shows its one-based desktop number, as in
`[Start] [1][_][_][_]`. Click a slot to switch. New windows open on the active
desktop. Each desktop has its own visible windows, input, window cycling,
window buttons, and remembered focus.

In **Start > Settings**, **Virtual desktops** has **-** and **+** buttons around a
block-style progress bar and a numeric count. It allows 1 through 4 desktops.
**Apply** changes the count, **Save** also persists it in `vtk.ini`, and **Reset**
returns to one. Reducing the count moves windows from removed desktops to the
last remaining desktop.

The window's `[=]` menu, also available from its appbar button, has a **Move to
desktop** submenu when multiple desktops exist. Moving a window leaves the
current desktop active. Raising an existing window on another desktop switches
to it. Owned modal dialogs follow their owner. Application-modal dialogs prevent
switching until dismissed. Tiling, cascading and shared-edge resizing keep
desktops independent.

```v
app.set_desktop_count(4)
app.switch_desktop(2)
app.move_window_to_desktop(mut window, 3)
```

`app.get_desktop_count()`, `app.get_active_desktop()` and `window.get_desktop_id()` expose the
current state. Use the methods above to change it so focus, menus and capture
are updated together. Desktop numbers are one-based. Invalid switch and move
requests return false. The default count is one.

## Clock actions

Set `app.clock_clicked` to handle clock presses in the desktop bar. The callback
receives the mouse event and app. It receives one event per left, middle, or
right press with zero-based screen coordinates. It works at either bar position
while the clock is visible, and it respects application-modal dialogs.

```v
app.clock_clicked = fn (event vtk.Event, mut app vtk.App) {
    mut menu := vtk.context_menu()
    menu.menu_item('Calendar...', fn (mut _ vtk.Ctl, mut app vtk.App) {
        if date := app.date_pick(app.top_window(), 'Choose date', time.now()) {
            app.notify('Selected ${date.year:04}-${date.month:02}-${date.day:02}', 1500)
        }
    })
    app.open_menu(menu, event.x, event.y)
}
```

This example also needs `import time`. The widgets demo opens the calendar
on a left click and its menu on a right click.

## Window lifecycle

| Operation | Lifecycle contract |
|---|---|
| `app.close(mut window)` | Checks close vetoes for the window and owned modal dialogs, then releases their terminal processes and input capture. Retains the tree until the next event-loop step, which disposes closed windows automatically. |
| `app.destroy_ctl(mut control)` | Honors close vetoes for registered windows, then disposes children and context menus, calls each `destroy` callback once, and detaches the control. |
| `app.quit()` | Checks every window's veto before closing anything, including windows opened by close callbacks. Stops the event loop only when all approve. |
| `app.fini()` | Forces final disposal of registered windows without calling `closing`, cancels pending hooks and input, and restores the physical terminal. A recursive call during final disposal returns immediately. |

A veto prevents toolkit cleanup. Side effects performed by callbacks remain.
Destroy callbacks run after their children have been disposed. Disposed controls
cannot be reattached or raised. Use `destroy_ctl` to dispose of detached
controls directly. `run()`
always calls `fini()` after its loop. In a custom loop, a false result from
`step()` releases the physical terminal. Call `fini()` to dispose of the app.

`app.close(mut window)` accepts owned windows and returns false for invalid
targets or vetoed requests. Closing an already closed window owned by the app
succeeds. A recursive close returns false while the window's close callback is
running. A callback that transfers a window to another app aborts the old app's
close request.

The child tree determines resource lifetime. Disposal clears `link`, typed
callback context, and callbacks after `destroy` runs. Shared editor buffers
and V-managed widget handles remain safe to hold. `fini` also releases queued
callbacks, input, notifications and render storage. Window actions require
window handles. Modal requests reject invalid owners and ownership cycles.
