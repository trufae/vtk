# Controls and layout

`vtk.Ctl` is the shared type for widgets, containers, and windows. Constructors
return control handles. Attach a child with `parent.add(mut child)` or use the
container's dedicated method, such as `add_tab` for tabs.

## Widget API

| Control | Constructor and common operations |
| --- | --- |
| Window | `app.window(title, width, height)`, `app.move(mut window, x, y)` |
| Label and separator | `vtk.label(text)`, `vtk.separator()`, `control.set_text(text)` |
| Buttons | `vtk.button(text)`, `vtk.toolbutton(text)`, `vtk.button_bar()` |
| Text fields | `vtk.entry(text, byte_limit)`, `vtk.multiline(text)` |
| Markdown | `vtk.markdown(text)`, `control.markdown_mode(mode)` |
| Boolean inputs | `vtk.checkbox(text, checked)`, `vtk.switch_ctl(text, on)` |
| Date picker | `vtk.date_picker(initial)`, `control.date()`, `control.set_date(date)` |
| Numeric inputs and progress | `vtk.slider(low, high)`, `vtk.spin(low, high)`, `vtk.progress()`, `vtk.spinner(text)` |
| Choices | `vtk.combo()`, `vtk.radio()`, `control.add_item(text)` |
| [Table](tables.md) | `vtk.table(fetch, row_count)`, `control.table_column(title, options)` |
| Tree | `vtk.tree()`, `control.tree_add(parent, text)`, `control.tree_selection()`, `control.tree_select(node)` |
| Tabs and groups | `vtk.tabs()`, `control.add_tab(title, mut child)`, `vtk.group(title)` |
| Layout containers | `vtk.box(vertical)`, `vtk.grid()`, `vtk.flow()`, `vtk.split(vertical, share)`, `vtk.scroll()` |
| Bars | `vtk.toolbar()`, `vtk.statusbar(text)` |
| [Canvas](terminal.md#custom-drawing) | `vtk.canvas(width, height, paint)` |
| [Chart](charts.md) | `vtk.chart(options)`, `control.set_chart(options)` |
| Menus | `window.add_menu(title)`, `menu.menu_item(title, callback)` |
| Context menu | `vtk.context_menu()`, `control.set_menu(mut menu)`, `app.open_menu(menu, x, y)` |

Numeric controls use `low` and `high` as bounds. `value` stores the current
number or selection index. Choices start with `value == -1`. Comboboxes use
`text_align = .left`, `.center`, or `.right` for both the selected value and
dropdown items. Alignment uses terminal cell widths and leaves the dropdown
arrow fixed on the right.

For trees, pass `none` as the parent of a root node. Use each node's `expanded`
flag to open branches. `tree_select(node)` schedules a redraw without firing
`changed`.

```v
mut tree := vtk.tree()
mut projects := tree.tree_add(none, 'Projects')
projects.expanded = true
tree.tree_add(projects, 'VTK')
window.add(mut tree)
tree.tree_select(projects)
```

Set `blocky = true` on a progress bar to draw two-cell blocks separated by
one-cell gaps. The default is a continuous bar. Both styles use the same
numeric bounds.

### Date picker

`vtk.date_picker(initial)` takes a `time.Time` and creates a Gregorian
calendar with weeks starting on Monday. `date()` returns the selected date
at midnight and `text` contains its ISO `YYYY-MM-DD` form. `set_date(date)`
uses the year, month, and day, clamps them to a valid date in years 1–9999,
and fires `changed` when the selection changes.

Click a day to select it. Arrow keys move by a day or week. Page Up and
Page Down change the month, and Shift or Ctrl with those keys changes
the year. Home and End select the month's first or last day. Press T or
click **Today** to return to today. Use `app.date_pick(owner, title, initial)`
for an OK/Cancel dialog that returns an optional date.

## Layout and sizing

Use `vtk.box(true)` for a vertical stack or `vtk.box(false)` for a horizontal
row with one cell between children. In grids, set a child's `row` and `col`
to indices from 0 through 64. Set `expand = true` so a child shares spare
space. Use `min_w` and `min_h` to set preferred minimum sizes. A button bar
docks at the bottom and aligns its contents to the right. Hidden controls and
inactive tab pages are excluded from layout and hit testing.

Apply `padding` to inset a control's content. Values are terminal columns on
the left and right and rows on the top and bottom. Padding defaults to zero.
Set the field when constructing the control and call `set_padding` for live
changes.

```v
text.set_padding(vtk.Insets{left: 1, right: 1, top: 1, bottom: 1})
```

`rect()` returns the full allocation. Use `content_rect()` for the inset
region in custom painters and mouse handlers. Padding contributes to preferred
size and is applied inside the window's client area, group frame, or control
allocation, in addition to built-in spacing such as an editor's line-number
gutter. Menu items, cells, and tree nodes share their container's layout.
Negative padding acts as zero. Oversized padding clips the content area.
Clicking editor padding can focus the editor while preserving its caret.
Buttons accept clicks throughout their allocation.

### Split panes

`split(false, share)` places two panes side by side. `split(true, share)`
stacks them. The first pane receives `share` thousandths of the available
space for values from 1 to 999. Use zero to size it from its preferred size.

```v
mut panes := vtk.split(false, 500)
panes.resizable = true
panes.add(mut sidebar)
panes.add(mut editor)
window.add(mut panes)
```

With `resizable = true`, dragging the divider lays out both panes live,
retains focus, updates `value`, and fires `changed` after layout. The ratio
is reused when the window resizes. Dragging respects each pane's minimum
when the available space fits both. A stationary click preserves the current
split. Use `separator()` to draw a standalone decorative line.

### Tabs

Call `pages.add_tab(title, mut child)` to add a page. The two-row header keeps
the selected tab visible as the strip narrows and uses ASCII outlines in
Serial mode. Set `pages.reorderable = true` to make both header rows draggable.
Reordering retains the selected page and its control state. Use the optional
`reordered` callback to update matching application data. Its indices are
zero-based, and `value` and `children()` reflect the new order when it runs.
The callback is separate from the `changed` event fired for tab selection.

```v
fn tab_moved(mut pages vtk.Ctl, from int, to int, mut app vtk.App) {
	// Move any matching application data from `from` to `to`.
}
```

Assign the handler with `pages.reordered = tab_moved`.

## Callbacks and updates

| Field | Signature | When to use it |
| --- | --- | --- |
| `changed` | `fn (mut vtk.Ctl, mut vtk.App)` | Button activation, value changes, or editor mutations. |
| `submit` | `fn (mut vtk.Ctl, mut vtk.App)` | Enter on a control that supports submission. |
| `keyfn`, `mousefn` | `fn (mut vtk.Ctl, vtk.Event, mut vtk.App) bool` | Handle input. Return true to consume the event. |
| `scrollfn` | `fn (mut vtk.Ctl, int, mut vtk.App) bool` | Handle row scrolling. Return true to consume it. |
| `closing` | `fn (mut vtk.Ctl, mut vtk.App) bool` | Return false to veto window closure. |
| `destroy` | `fn (mut vtk.Ctl, mut vtk.App)` | Release application-owned resources during disposal. |

Store shared callback state with `ctl.set_context(&state)` and recover it with
`ctl.context[State]()`, which returns an optional reference. Use the optional
`link` field to associate another control and unwrap it in the callback. The
`data` field can hold an application-defined `i64`.

Use widget methods for changes. `set_value`, `replace_selection`, `undo`,
`redo`, and `toggle_task` notify `changed` when an attached control's state
changes. Use `fire()` to invoke `changed` directly. Detached controls can be
initialized without an app. Attachment starts callback delivery for future
changes.

```v
mut progress := vtk.progress()
progress.set_value(10) // Prepare the initial value while detached.
window.add(mut progress)
progress.set_value(42)
```

`set_text`, `markdown_mode`, `vim_mode`, item and page additions, scrolling,
size limits, and tree changes schedule a redraw without firing `changed`.
After assigning public fields on an attached control, call
`control.invalidate()` to schedule a redraw.

## Ownership and tree operations

A subtree takes on the owning app when attached to one of its windows. This
also applies to nested controls built before attachment. `set_menu` attaches
a context menu with the control's ownership. A standalone menu takes on the
app when opened.

Use `add`, `detach`, `clear`, and `replace` to update the tree. `clear`
detaches children for later reuse. Use `app.destroy_ctl(mut control)` to
release a subtree and its resources. Detaching clears stale selections,
default buttons, and input capture. Windows stay at the root, and attachment
rejects cycles and disposed controls.

Moving a subtree to another window updates ownership for future callbacks.
Hover leave callbacks run before the transfer, and stale focus, capture, and
popups are dropped. Window management, scrolling, focus, destruction, and
dialog operations validate the owning app. Explicit attachment and
`app.dialog` can transfer a subtree. `app.raise` can adopt a detached window.

Use `parent_ctl()`, `children()`, `owner_window()`, `rect()`, and
`preferred_size()` to inspect the tree and geometry. `app.window_list()`
and `app.focused_ctl()` inspect app state. Arrays returned by
`children()` and `window_list()` are copies. Optional lookups such as
`top_window()`, `tree_selection()`, `hovered_ctl()`, and `hit()` return
`?&Ctl`. Unwrap them with an `if` guard or `or` block.

Call `app.layout()` to calculate geometry before reading positions or
setting up focus. For application-wide changes, `app.invalidate()` schedules
the next redraw. See [window lifecycle](application.md#window-lifecycle) for
close and disposal behavior.
