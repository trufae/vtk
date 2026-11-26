# Tables

Tables fetch cells from application data through `CellCallback`. Callback row and
column arguments, `value` (the active row), style coordinates and edit batches
always use **source IDs**. Sorting or moving a row/column changes only the view.
Tables default to single-row selection, equal-width columns and copy
support. Sorting, dragging, cell editing, paste and Tab navigation are opt-in.

This example displays two source rows. Add the function at module scope and
create the table when building a window.

```v
fn fetch_cell(_ &vtk.Ctl, row int, col int) string {
	rows := [['Pencils', '2.50', '101'], ['Paper', '5.00', '102']]
	return rows[row][col]
}
```

```v
mut grid := vtk.table(fetch_cell, 2)
grid.table_column('Name', width: 24, min_width: 8)
grid.table_column('Price', width: 12, numeric: true, align: .right)
grid.table_column('ID', width: 10, editable: false)
grid.table.selection = .cells // .rows (default), .columns, .cells, .none
grid.table.multi_select = true
grid.table.sortable = true
grid.table.resizable_columns = true
grid.table.reorderable_columns = true
grid.table.reorderable_rows = true
grid.table.row_numbers = true
grid.table.grid_lines = true
grid.table.tab_navigation = true
window.add(mut grid)
```

`table_column` returns its source column ID. Column options include `width` (zero
means equal-width automatic sizing), `min_width`, `max_width` (zero means no
explicit maximum), `align`, `numeric`, and `editable`. Reconfigure a column with
`table_configure_column(id, options)`, or change just its width with
`table_set_column_width(id, width)`. `table_autofit(id, limit)` measures its header
and cells. `table_column_width(id)`, `table_column_rect(id)` and
`table_cell_rect(source_row, source_column)` expose layout in terminal cells.

## Selection and coordinates

`table_select(x, y, x2, y2)` selects an inclusive rectangle using zero-based
**view** column/row coordinates. `multi_select` must be enabled for different
endpoints. The configured mode expands the rectangle to whole rows or columns.
`.none` disables selection and copy. `table_selection()` returns a normalized
`TableRange` (`x`, `y`, `x2`, `y2`) with `x == -1` for an empty selection.

```v
grid.table.selection = .cells
grid.table.multi_select = true
grid.table_select(1, 2, 4, 6) // B3 through E7 in the current view
range := grid.table_selection()
source_row := grid.table_row_at(range.y)
source_column := grid.table_column_at(range.x)
```

Use `table_row_at(view_row)` / `table_column_at(view_column)` and the inverse
`table_view_row(source_row)` / `table_view_column(source_column)` to translate
coordinates. Invalid coordinates return `-1`. `table_selected_column()` is a
source column ID. `set_value(source_row)` keeps its existing meaning and collapses
the row anchor. Custom mouse handlers that calculate a display row must translate
it before calling `set_value` or accessing application data.

Click to select. Shift-click, Shift-arrows, and dragging extend ranges when enabled.
In Cells mode, clicking/dragging the row-number gutter selects complete rows.
In Columns mode, drag headers to select columns. Alt-drag moves a column.
Arrows navigate in view order. Cells mode uses Left/Right for columns, Home/End
for the current row, Ctrl-Home/End for the table, and Page Up/Down for rows.
Ctrl-A selects all when multiple selection is enabled. Optional Tab / Shift-Tab
navigation wraps between cells. F6 moves focus out to another control.
Selection changes emit `changed`, including changes to the active column/range.

## Sorting and reordering

`table_sort(source_column, .ascending)` / `.descending` / `.none` work from code
regardless of the interactive `sortable` option. Sorting is stable, preserving
source order for equal keys. Text compares case-insensitively. `numeric: true`
compares numbers before text in ascending order. Supply `table.compare` for a
custom comparator `fn (&vtk.Ctl, left_row, right_row, column int) int`.
Negative, zero and positive results mean before, equal and after.

With `sortable` enabled, ordinary row-mode header clicks cycle ascending,
descending and source order. Other selection modes use Ctrl-click to sort,
leaving ordinary header clicks available for selection. Alt-Up/Down sorts the
active column. `table_sort_state()` returns the source column and direction.

`table_move_row(from_view_row, to_view_row)` and
`table_move_column(from_view_column, to_view_column)` move view entries without
mutating application data. Interactive column dragging follows the pointer and
reflows headers live. Drag a column boundary to resize it, or double-click
to fit its contents.
Alt-dragging row numbers moves rows and clears the sort indicator. Sorting and
moving entries collapse range anchors while preserving the active source cell.

`table.sorted`, `table.column_resized`, `table.row_reordered` and
`table.column_reordered` are optional notifications. Move callbacks receive
`(mut control, from_view_index, to_view_index, mut app)` after the move. Other
notifications use the usual control/app callback. They may close or destroy the
control. `changed` remains the selection notification.

Call `table_refresh()` after replacing or changing source data. It resets manual
row order and reapplies any active sort. VTK detects changes to `row_count` automatically.
Editing automatically reapplies active sorting, while retaining manual row order
when no sort is active. Simple unsorted tables allocate no per-row view mapping.
Shift-wheel and horizontal wheel events scroll columns while keeping row numbers fixed.

## Editing and clipboard

```v
fn apply_cells(mut grid vtk.Ctl, edits []vtk.TableCellEdit) ! {
    // Validate the entire batch, then write all edits to application data.
    // Each edit has a source row, source column and string value.
}

grid.table.editable = true
grid.table.pasteable = true
grid.table.edit = apply_cells
grid.table.edit_value = raw_cell // optional CellCallback, distinct from display
app.ctrl_c = .copy
```

F2, Enter, or typing opens a cell editor. Apply or Enter commits the edit, and
Escape cancels it.
Rejected edits retain their draft and display the returned error. Read-only
tables (`readonly`) and columns cannot be edited. `table_begin_edit()` opens the
same editor from application code. `table_apply([]TableCellEdit)` validates every
target and calls `table.edit` **once**, then refreshes sorting and emits
`table.edited`. The edit callback must validate the whole batch before mutating
application data and leave it unchanged on error. It can record the batch as
one undo action.

`table_selection_text()` and `app.copy_focus()` copy the selected rectangle as
TSV in view order, quoting tabs, newlines and quotes. `table.copyable` defaults to
true and can disable this. `table_paste(text)` applies TSV at the selection's
top-left cell, mapping every target back to its source ID. Ctrl-V and bracketed
paste use it when enabled. Out-of-bounds, read-only and malformed input reject the
whole batch before the callback. Delete/Backspace clears the selected cells in
one batch. `parse_table_data(text, delimiter)` provides the same strict quoted
CSV/TSV parser for importers.

## Cell colors

```v
grid.table_set_cell_style(2, 1, vtk.TableCellStyle{bg: vtk.blue, fg: vtk.white})
grid.table.cell_style = fn (_ &vtk.Ctl, row int, column int) vtk.TableCellStyle {
    return if row % 2 == 0 {
        vtk.TableCellStyle{bg: 0x1011820}
    } else { vtk.TableCellStyle{} }
}
```

Style coordinates and callback arguments use source IDs, so colors follow their
data through sorting/reordering. `fg` and `bg` default to `-1` (inherit), and
`attr` supports the existing `bold`, `underline`, etc. flags. Colors use the same
palette/truecolor encoding as the rest of VTK. A callback's explicit colors
override stored cell styles. Unset fields inherit them. `table_clear_cell_styles()`
clears stored styles, retaining the callback. Selection colors take precedence to
keep the selected area readable. The active cell also receives bold underline.

The [spreadsheet example](../app/spread/README.md) demonstrates this API
with formulas, undo/redo, workbook persistence, editable colors and sheet tabs.
