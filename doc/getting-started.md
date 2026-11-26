# Getting started

## Install V and VTK

Build V from its Git repository. On macOS and Linux, run these commands from
the directory where you want to keep the compiler. They require Git, Make, and
a C toolchain.

```sh
git clone https://github.com/vlang/v
cd v
make
export PATH="$PWD:$PATH"
```

The PATH setting applies to the current shell. Add the absolute path to the V
checkout to your shell's startup file to keep it across sessions. On Windows,
build with `makev.bat` and add the checkout directory to PATH. See the platform
notes in the [V installation guide](https://github.com/vlang/v#installing-v-from-source).

Install the toolkit through V's package manager.

```sh
v install https://github.com/trufae/vtk
```

VTK uses V's standard library and native OS bindings. It has no additional VPM
dependencies. If you manage modules by hand, place the entire checkout in a V
module search path as `vtk`. The root `v.mod` maps that module to `lib/`.

## Your first app

Save this as `main.v` in a directory for your app and run `v run main.v`.

```v
import vtk

fn pressed(mut _ vtk.Ctl, mut app vtk.App) {
	app.notify('Hello from V', 2000)
}

fn main() {
	mut app := vtk.new_app()
	mut window := app.window('Hello', 40, 12)
	mut body := vtk.box(true)
	mut help := vtk.label('Tab moves focus. Ctrl-C quits.')
	mut button := vtk.button('Press me')
	button.changed = pressed
	body.add(mut help)
	body.add(mut button)
	window.add(mut body)
	app.run() or { panic(err) }
}
```

`vtk.new_app()` creates the app and `app.window` registers a window sized in
terminal cells. The label and button share a vertical box. Click the button,
or focus it with Tab and press Enter, to show a notification. `app.run()`
runs the event loop and restores the terminal on exit. See
[Controls and layout](controls.md) and [App, windows and dialogs](application.md).

## Run the included apps and examples

Run these from the repository root after cloning
`https://github.com/trufae/vtk`. V resolves the local toolkit, so a separate
package install is optional for these commands.

| Command | Try it for |
| --- | --- |
| `v run app/desktop.v` | The shared desktop with Word, Slides, Spread, Paint, Calc, Clock, and Files in **Start → Programs**. |
| `v run examples/widgets.v` | Widget setup, layout, and callbacks in one gallery. |
| `v run examples/htk.v` | A port of the original HTK demo. |
| `v run app/word.v README.md` | Markdown editing, preview, alignment, and Unicode font styles. |
| `v run examples/vim.v README.md` | A standalone editor with Vim motions and commands. |
| `v run app/paint.v` | Canvas drawing and mouse input. |
| `make build/spreadsheet && ./build/spreadsheet --chart` | A spreadsheet with editable tables, formulas, and charts. |
| `v run app/files.v` | List, icon, and column views, multi-selection, and drag and drop between windows. |
| `v run examples/terminal.v` | A shell in a VTK window. |

Run `make` to build the apps, examples, VML compiler, and VML demos in
`build/`. Launch the desktop with `./build/desktop` or the spreadsheet with
`./build/spreadsheet`. See the [spreadsheet walkthrough](../app/spread/README.md).

For declarative layouts, run `make vml`. The compiler at `./build/vmlc`
turns a `.vml` file such as `dialog.vml` into a V file with a
`build_dialog(mut app)` function. Compile the generated file alongside the app.
Try `./build/vml-hello` or follow the [VML guide](../vml/README.md).

VTK is a standalone V port of the Borland-style HTK from
[AholyC](https://github.com/trufae/aholyc). The original HolyC library remains
in that project. VTK follows the repository's
[public-domain dedication](../COPYING).
