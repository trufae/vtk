# Contributing to VTK

To report a bug, include the command or smallest example that reproduces it,
the expected and actual behavior, and the output of `v version`. For display
or input bugs, also include your OS, terminal emulator, and any VTK renderer
settings. File reports in the [VTK issue tracker](https://github.com/trufae/vtk/issues).

## Set up a checkout

Install V from Git and make sure a C toolchain is available. Fork the
repository, clone your fork and create a branch for the change. The
[setup instructions](getting-started.md#install-v-and-vtk) cover the toolchain.

Use the [repository rules](../RULES.md) when changing code or reviewing a
patch. The toolkit favors small changes that preserve control ownership,
callback behavior, and lifecycle contracts. Add a focused regression for a
bug or a change to observable behavior. When a public API changes, update
its callers, examples, tests, and docs together.

| Directory | What lives there |
| --- | --- |
| [lib/](../lib/) | The `vtk` module, its public API, widget tests, and native terminal bindings. |
| [render/](../render/) | Cell rendering, ANSI diffs, scroll detection, and the memory presenter. |
| [examples/](../examples/) | Small runnable demos and the widget gallery. |
| [app/](../app/) | Desktop and standalone apps, with implementations under `app/programs/` and `app/spread/`. |
| [vml/](../vml/) | The VML parser, generator, descriptor, and example UIs. |
| [doc/](README.md) | API guides and developer documentation. |

## Verify your change

Run the commands relevant to the change from the repository root.

| Command | What it checks |
| --- | --- |
| `v test lib/presenter_test.v` | One test file. Replace the path with the tests for your change. |
| `make test` | Regenerates VML outputs when needed and runs the repository's V tests. |
| `make all` | Builds the apps, examples, VML compiler, and generated example UIs. |
| `make check-windows` | Type-checks app, example, and VML entry points for Windows. |
| `git diff --check` | Finds whitespace errors in the patch. |

Use `v fmt -w path/to/changed.v` on changed V source. If you edit `.vml`
fixtures, the generator, or `vtk.vmlt`, run `make vml` and include any
changed generated `ui.v` files. The VML tests compare the checked-in outputs
with the markup. See [VML](../vml/README.md).

For layout or widget tests, use the [memory presenter](terminal.md#terminal-presenters)
to dispatch input and assert the resulting screen or state without a tty.
For changes to the real terminal driver, run the affected app in a terminal
and exercise the changed input, resize, or cleanup behavior. The suite
includes Unix PTY tests. Verify Windows console and ConPTY runtime changes on
Windows and record which checks you ran.

## Open a pull request

Describe what changed, how to reproduce the original issue if applicable,
and which checks passed or failed. Include a screenshot or headless snapshot
for visual changes. Keep the patch focused so reviewers can see the behavior
change alongside its tests and documentation.
