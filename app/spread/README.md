# VTK Sheets

A spreadsheet example built on the callback-backed table API. Run it from the
VTK checkout:

```sh
make build/spreadsheet
./build/spreadsheet
./build/spreadsheet budget.vtksheet
./build/spreadsheet --chart
v -d vtk_snapshot -o build/spreadsheet-preview run app/spread.v --chart
```

The initial workbook has a Budget sheet with working formulas and a Notes sheet.
New sheets start at 40 rows × 12 columns. CSV imports grow to fit, up to 1000 rows
and 100 columns. The formula bar shows the active cell's original text; the grid
shows its calculated value. F2, Enter, or typing opens an editor; Escape cancels.

Use the Rows / Columns / Cells / No selection selector to change selection mode.
Multiple enables ranges. Drag or Shift-click / Shift-arrows to extend a selection;
Ctrl-A selects all. Tab / Shift-Tab moves between cells; F6 leaves the grid for
the toolbar. Ctrl-C copies selected cells as TSV. Ctrl-V or bracketed paste applies
one validated edit batch, and Delete clears the selection. The Edit menu also
provides Copy and Paste. Undo/redo covers cell edits, bulk paste, deletion and
background colors; Ctrl-Z / Ctrl-Y operate on the current sheet.

Select a cell range and click **Chart** (also in the Data menu) to plot it as
grouped columns, horizontal bars or connected lines. For a block with several
columns, the first selected column supplies category labels and the remaining
columns supply series. A single column uses cell addresses as categories. A
first row of text headings supplies series names. For example,
select A1:D4 in Budget to chart Quantity, Unit cost and calculated Total by item.
Blank, text and error cells become gaps rather than zero values. Charts follow
the current row/column view order and keep the formulas' full numeric precision.

The chart dialog lets you change its type, chart title, X/Y axis titles, value
minimum/maximum and each series' RGB color. Press Apply (or Enter in a field) to
update titles and bounds. Blank bounds use automatic scaling, including zero;
switching to bars swaps the category and value axes. Escape closes the chart.
Charts are previews of the selected values at opening time; their settings are
not saved in the workbook. `--chart` opens a chart of the first four rows and
columns on startup. Build with `-d vtk_snapshot` for a headless chart preview.

Ctrl-click a column header cycles ascending, descending and source order. The
toolbar also sorts the active column. Drag headers to reorder columns; drag their
right boundaries to resize, or double-click a boundary to fit its contents.
Alt-drag a row number to reorder rows. Drag sheet tabs to reorder the workbook.
In Columns mode, ordinary header dragging selects columns; Alt-drag still moves
them. Row numbers and the formula bar always identify the original source cell.

Formulas support arithmetic (`+ - * /`), parentheses, unary signs, decimal and
exponential numbers, A1 references, and `SUM`, `AVG`, `MIN`, `MAX`, `COUNT` with
comma-separated expressions or ranges, for example `=SUM(D2:D8)*1.2`.
Ranges ignore blank and text cells. Errors such as division by zero, invalid
references and cycles appear in the grid. Calculations keep full floating-point
precision; the grid displays six decimal places. Formulas refer to cells within
their own sheet; cross-sheet references and formula translation on copy are not
implemented in this example.

Sorting and manual row/column movement reorder the **view**, retaining source
cell addresses and formula references. They do not rewrite the source data.
View ordering and column widths reset on reopen. Sheet tab order, raw cell values,
formulas and chosen background colors are saved in the `.vtksheet` JSON workbook.
The File menu imports CSV as a new sheet and exports the current sheet's raw
values/formulas in source order. Ctrl-S saves, Ctrl-Shift-S saves as, Ctrl-O opens,
Ctrl-N adds a sheet, and Ctrl-Q quits with an unsaved-change check.

The model, formulas and UI are separate files. The UI uses `table.edit` for atomic
batches, `table.edit_value` for raw text, `table.compare` for precise numeric
sorting, `table.cell_style` for calculated/header/custom colors, and the public
selection and view/source coordinate methods. It does not access private widget
fields. See the [table API](../../doc/tables.md) and [chart API](../../doc/charts.md).
