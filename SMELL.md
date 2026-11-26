# API design smells

Keep IDs stable when updating statuses. Follow [RULES.md](RULES.md) when addressing an item.

| ID | Status | Smell | Short description |
|---|---|---|---|
| API-01 | ✅ Fixed | 🧭 [Misplaced `Ctl.close()`](lib/window.v) | Removed `Ctl.close()`; window closing belongs to `app.close(mut window)`. |
| API-02 | ✅ Fixed | 🪪 [Inconsistent ownership checks](lib/core.v) | Shared checks reject foreign-app operations and discard stale input after ownership transfers. |
| API-03 | 🟡 Partial | 🔓 [Exposed mutable internals](lib/core.v) | Tree and backing storage are protected; public `text`, `edit` and `md.mode` still let callers bypass editor invariants. |
| API-04 | ✅ Fixed | 🧩 [Overloaded fields](lib/core.v) | Explicit fields separate entry limits, row counts, tree state, dialog results and popup ownership; `link` holds callback context. |
| API-05 | 🔎 Open | ✏️ [Inconsistent text mutation](lib/core.v) | `set_text()` bypasses editing checks, resets history and emits no change callback. |
| API-06 | ✅ Fixed | 🧹 [Fragmented lifecycle](lib/window.v) | Close and quit share veto checks and resource/input cleanup; destroy and fini share disposal with once-only callbacks. |
| API-07 | 🔎 Open | 🧨 [Unsafe callback state](lib/core.v) | Ordinary callbacks recover application state through unchecked `voidptr` casts. |
| API-08 | 🔎 Open | 🔔 [Attachment-dependent notifications](lib/core.v) | Mutations deliver callbacks only while controls have an owning app. |
| API-09 | 🔎 Open | 🔄 [Hidden modal reentrancy](lib/dialog.v) | Blocking dialogs run another event loop before the initiating callback returns. |
| API-10 | ✅ Fixed | 🕳️ [Hidden nullable references](lib/query.v) | Nullable lookups and callback associations use options; dialog owners and tree parents accept `none`. |
| API-11 | 🔎 Open | 🤐 [Ambiguous failure results](lib/editor.v) | Rejection and unchanged state share `false`; some invalid operations silently return. |
| API-12 | 🔎 Open | 🎨 [Mixed color encodings](lib/desktop.v) | Raw RGB and tagged toolkit colors share `int`, requiring manual conversions. |
| API-13 | 🔎 Open | ⚙️ [Implicit startup settings](lib/loop.v) | Initialization loads shared settings, potentially overriding configuration and hiding errors. |
| API-14 | ✅ Fixed | 🪟 [Unchecked window targets](lib/window.v) | Window actions share kind/ownership guards; dialogs reject invalid owners and modal cycles before mutation. |
| API-15 | 🔎 Open | 🌳 [Unchecked tree parents](lib/layout.v) | `tree_add` accepts parents from other trees and can select a node outside its own tree. |

API-03 covers direct field writes; API-05 covers the `set_text` mutation contract.
API-06 retains distinct close and disposal operations with shared cleanup;
see the [window lifecycle contracts](doc/application.md#window-lifecycle).

## Memory, allocation and complexity review

Reviewed widget ownership/lifecycle, rendering/layout, editors/Markdown/Vim,
input and native terminal transports, settings/menus/desktops, examples, and
the VML parser/generator. Local module dependencies are one-way: examples use
VTK; the VML compiler uses its descriptor and standard libraries. Widget parent
backlinks and application associations form GC-managed graphs; retained roots,
caches and callbacks determine whether those graphs can be collected.

| ID | Status | Finding |
|---|---|---|
| MEM-01 | ✅ Fixed | Reuse the screen front buffer; avoid per-cell rune arrays and glyph allocation during fills. Build snapshots with one string builder. |
| MEM-02 | ✅ Fixed | Disposal clears callback contexts and associations; detachment clears desktop-focus and resize-cache references. Shutdown releases queues, buffers and the native driver's global reference. |
| MEM-03 | ✅ Fixed | The event loop disposes closed windows on its next step, so desktop sessions do not accumulate closed document trees. |
| MEM-04 | ✅ Fixed | History reset/branching and popup removal release discarded backing storage; undo/redo clear popped slots. I/O readers reuse owner-held buffers, released on close; closed terminals discard pending input. |
| MEM-05 | 🔎 Open | Every widget allocates an `Edit` and embeds Markdown state, even for buttons and menus. Revisit editor state ownership together with API-03/API-05; preserve shared buffers. |
| MEM-06 | 🔎 Open | Large documents rebuild glyph/layout arrays; input, live terminal backlogs and undo history have no explicit memory limits. Profile representative workloads; limits need clear rejection/backpressure contracts. |

The existing Unicode/layout algorithms, native handle cleanup and VML value-tree
model remain in place. Replacing them with generic walkers, pools or a new
ownership framework would add complexity without evidence of a benefit.

Measured with V `-prod`, the GC allocation counter, and the median of three
runs against the working-tree snapshot from before this review. Allocations
are cumulative during each workload; output checksums matched.

| Workload | Allocated before → after | Median runtime before → after |
|---|---|---|
| 300 fills and ANSI diffs of a 120×40 screen | 174.33 MB → 1.79 MB | 148.7 ms → 55.5 ms |
| 30,000 idle steps with one open window | 1.44 MB → 0 B | 1.268 ms → 0.916 ms |

These measurements cover the rendering and idle paths. Large-document and
backlogged-terminal behavior remain separate profiling work under MEM-06.
