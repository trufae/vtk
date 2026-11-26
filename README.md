# VTK — Vorland TermKit

**Retro desktop apps, right in your terminal.**

Build windowed terminal apps in V with Borland-style widgets, mouse and keyboard
input, and a built-in desktop. Open an editor, chart spreadsheet data, or run
a shell alongside your own tools.

![VTK desktop with overlapping terminal windows and widgets](vtk.jpg)

## Install

We recommend [building V from Git](https://github.com/vlang/v#installing-v-from-source).
With `v` on your PATH and a C toolchain installed, add VTK to your project.

```sh
v install https://github.com/trufae/vtk
```

Use `import vtk` and follow the [first-app guide](doc/getting-started.md#your-first-app).

## Run the desktop

```sh
git clone https://github.com/trufae/vtk
cd vtk
v run app/desktop.v
```

Open **Start → Programs** to try Word, Slides, Spread, Paint, Calc, Clock,
Files, or Terminal. For a tour of the toolkit, run `v run examples/widgets.v`.

[Documentation](doc/README.md) · [Contributing](doc/contributing.md) · [License](COPYING)
