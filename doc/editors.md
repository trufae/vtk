# Editors and Markdown

## Text editing

Use `vtk.entry(text, byte_limit)` for single-line input, with a limit of zero
for unlimited text. Set `secret = true` for password masking. Use
`vtk.multiline(text)` or `vtk.markdown(text)` for longer documents. These
controls support undo/redo, line numbers, wrapping, and scrollbars.

Editor positions and selection anchors are UTF-8 byte offsets. Navigation
and editing preserve character boundaries. Read offsets with `selection()`
or `caret_position()`. Make undoable edits with `replace_range(from, to, text)`
or `replace_selection(text)`. Use `begin_edit_group()` and `end_edit_group()`
to make several changes one undo step. Use `set_text(text)` to load new
contents and reset selection and undo history. It can load read-only controls
and skips edit validation and the `changed` callback.

Multiline and Markdown controls expose three wrapping modes:

```v
text.set_wrap_mode(.none)      // original lines with horizontal caret scrolling
text.set_wrap_mode(.character) // wrap at display-character boundaries
text.set_wrap_mode(.word)      // prefer whitespace boundaries; split overlong words
mode := text.wrap_mode()
```

Wrapping preserves source text, selection, caret byte positions, and undo
history. Word wrapping preserves whitespace and whole Unicode graphemes.
Trailing whitespace can hang beyond the right edge. Tabs use the
configured `md.tab_width` and recompute their stops on each display row.
The default remains no wrapping for multiline controls and character wrapping
for Markdown. Existing `wrap` and `md.no_wrap` flags remain supported. Entries
are single-line controls and reject wrapping modes. VTK Word's View menu offers
all three modes and stores its View settings in `~/.vtk-word.ini`. VTK Vim accepts
`:set nowrap`, `:set wrap` / `charwrap`, and
`:set wordwrap`. The widgets example's Text tab demonstrates word wrapping.
Rendered Markdown tables retain their separate column layout and wrapping.

Set a multiline control's `syntax = .diff` to highlight unified diffs with
red deletions, green additions, cyan hunks and bold file headers. Scrolling,
wrapping and selection preserve the highlighting. `.plain` is the default.

Mouse wheel reports keep all four directions distinct. Vertical panels
ignore horizontal wheel and trackpad input. Wrapped editors scroll by display rows, preserve their caret and
selection, and retain mouse capture when a wheel event arrives during a drag.

## Markdown modes and layout

Set a Markdown control's presentation with `viewer.markdown_mode(mode)`.

| Mode | Presentation |
| --- | --- |
| `.edit` | Rendered and editable. This is the default. |
| `.source` | Editable source. |
| `.read` | Rendered, with text editing disabled. |
| `.source_read` | Source, with text editing disabled. |

The renderer handles headings, emphasis, inline code, links,
lists, task checkboxes, quotes, fenced code and pipe tables. Tables support
left/center/right alignment, inline formatting and links, escaped pipes and
code spans containing pipes. Short columns keep their natural widths while
long cells wrap to the available or page width. Resizing recomputes the layout.
Set `md.no_wrap` for natural table widths and horizontal scrolling. An explicit
`md.column_width` caps the table and shrinks its columns to fit. Table borders
are display glyphs. Selection, mouse hit testing, and copying use the
original UTF-8 Markdown source. Fenced examples and source modes stay literal.
Inline code accepts matching runs of multiple backticks. Fences retain source rows.
Code blocks use a small single-pass tokenizer for common keywords, strings,
numbers and comments, including unknown or omitted language tags. `diff` and
`patch` fences use unified diff colors. Untagged blocks detect diff headers.
Use a `text` or `plaintext` fence to keep a block uncolored. Highlighting retains
source positions and code shading. Set `code_block.fg` to override the colors.
In rendered read mode, click a task checkbox or press Space on it to toggle it.
In rendered edit mode, double-click the checkbox. A toggle changes the task's
state byte as one undo entry. Set `md.task_interactive = false` for a viewer
that leaves tasks read-only. Set `md.linkfn` to a
`fn (mut vtk.Ctl, string, mut vtk.App)` callback to receive URLs on click
in read-only views or with Ctrl-click. Rulers, column width, page separators,
and current-section layout are configurable through `md`.
`md.column_width` caps wrapped rows and the top ruler. Use `0` for the whole view.
`markdown_align` wraps the selected paragraphs in htk's Pandoc fenced divs
(`::: {.htk-align-center style="text-align:center"}` ... `:::`), and rendering
shifts or justifies the rows inside them. `markdown_align_at` reports the fence
containing an offset. Code blocks and tables are never rewritten.

## Markdown styles

Markdown appearance is configured per control through `md.styles`, separately
from parsing and layout. Inline code uses normal text colors and a slight
background tint. Fenced blocks use the same tint, including blank lines.
These defaults follow dark and light theme changes.

```v
viewer.md.styles = vtk.MarkdownStyles{
    code_shading: 5
    inline_code: vtk.MarkdownStyle{ attr: 0 }
    code_block: vtk.MarkdownStyle{ attr: 0 }
    link: vtk.MarkdownStyle{ attr: vtk.underline }
}
```

Each element style accepts optional `fg` and `bg` colors and an `attr` mask.
Styles are available for text, headings, inline code, code blocks, links, quotes,
table headers and table borders. Unset colors inherit or use the active theme.
Attributes add to explicit Markdown emphasis. `code_shading` mixes a percentage
of foreground into the background, clamped to 0–100 with a default of 6.
Set it to 0 to disable automatic shading. Explicit code backgrounds take priority. Selection colors
override code styling, and disabled controls retain the theme's dim foreground.

## Vim mode

`control.vim_mode(true)` or `app.vim_set(true)` enables per-editor Normal,
Insert, Visual and Visual-line modes. Motions include h/j/k/l, w/b/W/B,
0/^/$ and gg/G. Edits include i/a/I/A, o/O, J, x, dd/yy, dw/cw, p/P, undo,
and redo. Insert mode also supports Emacs-style movement, cuts, paste, and
transpose. Insert sessions and changes group into one undo step. Cursor
shape follows the focused editor's mode. With Vim mode enabled, j/k also
move the selection in tables, trees, radio lists and tabs.

## Clipboard

Use `app.clipboard_set(text)`, `app.clipboard_text()`, and `app.copy_focus()`
for the app clipboard. Strings preserve explicit lengths, including NUL.
Set `app.ctrl_c` to `.quit`, `.ignore`, `.copy`, or `.callback` for
Ctrl-C behavior. The callback option invokes `app.ctrl_c_handler`. Set
`app.native_clipboard = true` to additionally send copies through OSC 52.
Ctrl-C and Tab are forwarded to a focused terminal control. Ctrl-Tab switches
windows.

## Unicode font styles

Unicode font styles are text substitutions, so they can be used in labels,
buttons, or any other text. The terminal font needs the corresponding glyphs.

```v
styled := vtk.font_convert('Hello 123', .bold)
label := vtk.label(styled)
markup := vtk.font_format_tags('<italic>Hello</italic> <bold>world</bold>')
plain := vtk.font_translate(styled, .bold, .none)
style := vtk.font_style_from_name('sansserifbold') or { vtk.FontStyle.none }
```

The styles are `none`, `bold`, `italic`, `script`, `doublestruck`,
`underline`, `strikethrough`, `fraktur`, `bolditalic`, `sansserif`,
`sansserifitalic`, `monospace`, `boldscript`, `boldfraktur`, `sansserifbold`,
`sansserifbolditalic`, `openface`, and `smallcaps`. Conversion follows aholyc:
it styles ASCII letters and supported digits, leaving other characters intact.
Translation requires the source style. Unchanged characters and naturally
occurring styled Unicode can be ambiguous. Tags support a single level.
Unknown paired tags lose their wrapper, and unmatched tags remain literal. ASCII fallback
replaces unsupported glyphs when displaying the text.
