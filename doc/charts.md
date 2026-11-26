# Statistical charts

`chart(Chart{...})` creates an expanding, non-focusable chart control. Set its
`min_w` / `min_h` for a preferred minimum size, and use it in ordinary boxes,
splits, groups or tabs. Charts honor clipping, padding, themes and Serial/ASCII
rendering. Available cells determine how much detail fits. Small charts may
omit labels and narrow series.

```v
mut plot := vtk.chart(vtk.Chart{
    kind: .columns // .bars for horizontal bars; .lines for connected points
    title: 'Quarterly sales'
    labels: ['Q1', 'Q2', 'Q3', 'Q4']
    series: [
        vtk.ChartSeries{name: 'Actual', values: [f64(12), 18, 15, 24], color: vtk.cyan},
        vtk.ChartSeries{name: 'Plan', values: [f64(15), 16, 20, 22], color: vtk.color_rgb(255, 180, 60)},
    ]
    x_axis: vtk.ChartAxis{title: 'Quarter'}
    y_axis: vtk.ChartAxis{title: 'Sales (€)', minimum: f64(0), maximum: f64(30), ticks: 4}
})
window.add(mut plot)
```

`Chart.kind` chooses grouped vertical `.columns`, grouped horizontal `.bars`,
or `.lines`. Series share category positions and a numeric scale. `labels`
provides category names. Missing names fall back to one-based indices. Series
may have different lengths. Missing values and non-finite values (`math.nan()`
for an explicit gap) draw nothing and break lines. Negative values extend from
the zero baseline in the opposite direction. All-zero and constant data have a
usable automatic range. A chart without finite data displays “No data”.

Each `ChartSeries` has a `name`, `values []f64` and `color`. Negative series colors
use a repeating palette. Explicit colors accept the standard ANSI constants,
`color_rgb(r, g, b)` and `color_256(index)`. `Chart.fg`, `bg` and `axis_color`
inherit the surrounding theme when negative. `legend` and `grid` default to true.
Chart and axis titles are optional. The Y title is displayed horizontally above
the plot, and the X title below it.

`ChartAxis` defines `title`, optional `minimum` / `maximum`, `ticks` (default 5,
clamped to 2–20 and reduced to fit), and `include_zero` (default true).
Columns and lines use X for evenly spaced categories and Y for numeric values.
Bars use Y for categories and X for numeric values. Numeric bounds, ticks and
`include_zero` apply only to the numeric axis.

Unset numeric bounds are derived from finite data. Set `include_zero: false` to
fit a line chart's scale to its values. VTK ignores non-finite bounds and
uses automatic scaling when `minimum >= maximum`. Explicit
bounds clip bars and line segments to the plot, without drawing outside it.

Use `control.set_chart(options)` to replace the configuration, copy the input
labels/series/value arrays and schedule a redraw. It emits no `changed` event.
Alternatively, edit `control.chart` directly and call `control.invalidate()`.
Destroying the control releases its chart data. Call `set_chart` again to
refresh a chart from updated application data.

VML supports `Chart options={chart_options};`, where `chart_options` is a V
`vtk.Chart` expression (the default is an empty chart).

The [spreadsheet example](../app/spread/README.md) plots selected
cells, evaluates formulas and exposes type, title, axis and series color controls.
