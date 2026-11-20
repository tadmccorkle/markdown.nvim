# Markdown table editing: design and open questions

## First implementation (historical; revised by the accepted next pass below)

- Operate on GFM pipe tables identified by the Markdown tree-sitter parser, not
  text that merely looks like a table (especially fenced code).
- `:MDTableFormat` formats the table at the cursor; `:[range]MDTableFormat`
  formats whole tables intersecting the range; `:MDTableFormatAll` formats the
  document. Formatting is explicit, not an automatic save hook.
- Canonical output uses outer pipes, one space of cell padding, equal display
  widths per column, and the delimiter row's left/right/center alignment.
  Unspecified alignment is displayed left-aligned but retains no colons.
  Keep at least three dashes per delimiter cell. Trim cell-edge whitespace,
  preserve inline Markdown and escaped pipes, and retain surplus cells instead
  of silently dropping text. Missing cells are padded empty. Tabs are expanded
  for predictable widths; Unicode uses Neovim's display-width calculation.
- Preserve block quote/list prefixes, including the first list marker. New body
  rows use the delimiter row's continuation prefix. Tables need not have outer
  pipes on input. The delimiter row is structural, not a selectable data row.
- `:MDTableEdit` opens a scratch floating preview, initially selecting the cell
  under the source cursor (the delimiter selects the header). No default global
  keybindings are added. Public Lua functions and `<Plug>` maps enable custom maps.
- `h/j/k/l`, arrows, Tab/Shift-Tab navigate cells, including headers; movement
  clamps at edges (Tab wraps). `Enter` or `i` opens a second, single-line cell
  float in Insert mode. `Ctrl-s` accepts; `Esc` cancels from either mode.
  Normal-mode Enter also accepts. This avoids stealing Enter from Insert mode
  and leaves normal editing available inside the cell.
- `o/O` inserts a body row below/above; on the header either inserts the first
  body row. `a/A` inserts a column after/before. New columns default to left
  alignment without a colon. The inserted row/column is selected.
- `s` commits the formatted table and closes; `q`/`Esc` cancels all staged edits.
  A short guide is displayed below the table. Source changes are one buffer edit,
  hence one undo step in ordinary interactive use. Nothing writes the file.
- Reject saving if the source buffer changed while the editor was open (even
  outside the table), disappeared, or became nonmodifiable. Never overwrite
  concurrent edits. Source-window closure and external float closure must not
  leak scratch buffers. Small terminals should get bounded, scrollable floats.

## Deliberate limits and questions for follow-up

- Is a transactional editor preferable to live updates? Current choice makes
  cancellation useful and avoids undo noise, but source windows do not preview.
  > I think the current transactional behavior is fine, so long as we plan for configurable key mapping support. I would like to maintain an undo/redo tree though if possible. When editing the table this would be at the operation level (insert column, insert row, delete row, edit cell, etc.).

- Are `a/A` sufficiently memorable for columns? Could use `ic/ac`, configurable
  maps, or a help popup later. `s` commits; `q` always discards, without a prompt.
  > no prompts is good, maybe we can create a hook or lifecycle event later if someone wants to add this.
  > Keymap and behavior discussion later, below.

- Should Tab grow the table at its last cell? Initially it wraps without mutation.
  > No, it should not. current behavior is good.

- Should deletion, moving rows/columns, sorting, and changing alignment be added?
  These are useful follow-ups, not necessary for safe insertion/editing. Alignment
  is currently inherited from the source delimiter row.
  > yes deletion, yes moving (delete/yank and paste), no sorting, and yes change alignment - Keymap and behavior discussion later, below.

- Header insertion/deletion has semantic consequences. Keep exactly one header;
  row insertion at the header creates body rows rather than replacing it.
  > lgtm

- Multiline cells are not native GFM. The cell editor rejects physical newlines;
  use inline `<br>` explicitly. Raw unescaped pipes entered in a cell are escaped
  on acceptance, including inside code spans (GFM requires this).
  > cell editor should also replace physical newlines with <br>
  > additionally: unescape pipes and <br> for cell edits (might make it a config option)

- Very wide Unicode glyphs are measured by Neovim, not Markdown rendering. Emoji,
  conceal, proportional fonts, and rendered inline styles may look different.
  > lgtm

- Blank/irregular rows follow tree-sitter's table boundary interpretation. HTML
  tables, table creation, automatic typing-time formatting, and non-GFM dialects
  are out of scope. Formatting normalizes optional outer pipes and whitespace.
  > lgtm

- A conservative whole-buffer changedtick conflict check could later become an
  extmark-based table-only conflict check. For now, cancel and reopen after edits.
  > sure, fine as is right now, but should have a way to offload current table somewhere if it cannot be saved

- Configurable float styling, keymaps, and default mappings can follow feedback;
  the initial UI uses standard editor-relative rounded floats and no new config.
  > yes, let's stick with no new config for now, but ideally most everything will be configurable (float styling, keymaps, transactional vs live, etc.)
  > all operations in the floating window should support more than one keymap (for example, tab, `]`, and right-arrow could all be next cell instead of just tab)

- float behavior discussion:
  > opening the table editor when no table is in cursor context should start with a default 1 header 1 cell table.
  > There should be separate modes for navigating the table - one for current implementation, and another for navigating and interacting with the actual cell contents like normal vim (the buffer can still prevent text modification outside of its supported actions).
  > current cell shouldn't be sticky - if I jump (`<C-u>`/`<C-d>`) to a cell or click with the mouse somewhere, the active cell should move accordingly (or as close as possible if I click on a border).
  > the float should maintain position (centered as the width/height changes) and have a consistent and configurable left/right/top/left offset from the main neovim tab content.
  > when the float must scroll horizontally to display all cells, navigating all the way to the right should attempt to put the entire cell content on the screen and, when that is not possible, align the left-most part of the cell with the left side of the float so as much content possible is displayed.
  >
  > inserting column before/after should be different, maybe `ci` and `ca` by default.
  > `dd` should delete current row and allow it to be pasted above/below with `P`/`p` (match standard vim behavior here).
  > columns should also be able to be deleted and pasted before/after with `P`/`p`, although I don't have a good keymap in mind.
  > likewise, rows and columns should be yankable (`yy` to yank a row, not sure about column) and pastable like deletion.
  > likewise, cell contents should be deletable, yankable, and pastable, where pasting a cell will overwrite the target.
  > alignment of the current column should be controlled from anywhere in the column - either cycling through or by a keymap with a suffix that specifies what alignment to choose.
  >
  > I think it also makes sense to have a config options for the float editor to "minify" tables on confirm, with the default being to format them as it does currnetly.
  > 
  > in addition to the float edit mode, I'd like most capabilities (navigate by cell, open cell editor, copy within cell, insert column, insert row, etc.) to be exposed via `<Plug>` mappings - some things don't need to be, like yanking/deleting a row).

- Should deletion, moving rows/columns, sorting, and changing alignment be added?
  These are useful follow-ups, not necessary for safe insertion/editing. Alignment
  is currently inherited from the source delimiter row.

## Accepted next pass

The follow-up discussion approved the following behavior. These decisions supersede
conflicting descriptions in the historical first implementation above; the review
comments are retained for context.

- Keep transactions and defer public configuration, live updates, minification,
  sorting, and lifecycle hooks. Opening outside a table stages one header cell.
  Saving replaces a blank line or inserts after a nonblank line with blank-line
  separation. Cancellation does not change the source.
- Default to cell navigation; Ctrl-g toggles a non-default content-navigation mode.
  In content mode the preview stays nonmodifiable, but native Vim motions, scrolling,
  and Visual selections work. Table actions still work at the current cursor. Esc
  returns to cell navigation without closing; q discards from either mode. The
  active cell follows cursor movement and mouse clicks, with nearest-cell targeting
  on borders. Cell-motion maps return only when cell navigation is reentered.
- No inline keymap guide or key hints in titles. Normal-mode ? opens context-specific
  keymap help (including aliases); q/Esc/? closes that popup. Floats have filetypes
  markdown_table_editor, markdown_table_cell, and markdown_table_help, plus a
  b:markdown_table_role marker. Titles identify the surface and navigation mode.
- Center floats in the usable tab area with consistent margins and recenter on
  growth, shrinkage, and terminal resize. Reveal a cell's full text when possible;
  if oversized, align its beginning with the left edge of the preview.
- ci/ca insert columns before/after. dd/yy delete/yank rows; dc/yc delete/yank
  columns; dx/yx clear/yank cells. P/p pastes rows above/below, columns before/after,
  or overwrites the current cell, based on an editor-local typed register. Header
  deletion is forbidden, header yanks paste as body rows, and deleting the last
  column is forbidden. Paste expands dimensions rather than losing copied data;
  copied columns retain alignment. Cell yanks additionally copy decoded text into
  Vim's unnamed register. Clipboard/register state is not undone.
- al/ac/ar/an select left/center/right/unspecified column alignment. Each model
  mutation is one history operation. u/Ctrl-r undo/redo; g-/g+ traverse chronological
  history states including retained branches. Yanks, navigation, and mode switches
  are not history operations. Source commit remains one ordinary buffer edit.
- Cell floats decode escaped pipes and case-insensitive <br>, <br/>, or <br /> tags.
  Physical newlines encode as <br>, and pipes are escaped on acceptance. Cell-local
  text undo remains native Vim undo; accepting is one table-history operation.
- :MDTableExport opens the staged table, without container prefixes, in a regular
  Markdown scratch split. It does not save, discard, or weaken conflict checking.
- Shared actions and <Plug> maps support cell navigation, cell editing/copying,
  row/column insertion, and alignment directly in source buffers as well as previews.
  Source mutations commit immediately; source cell editing uses only the cell float.
  A conflict promotes that staged edit to the full editor for export or cancellation.
- Implementation keeps key aliases in action binding lists, ready for later
  configuration, but adds no public config options in this pass.

## Float interaction follow-up

- Dot repeats the last successful table deletion (row, column, or cell). Visual-line
  multi-row deletion records its row count; repeat deletes that many rows at the
  current cell, clipped at the end. Header and last-column protection still apply.
  No-op/protected deletions and yanks do not replace the remembered deletion.
- Visual-line d/x deletes and y yanks selected data rows; the delimiter is ignored.
  Header deletion is skipped even when a selection also contains body rows, while
  header yanks are allowed. P/p inserts a copied group in order, above/below the
  active row, as one undoable operation. Native characterwise Visual yanking is
  preserved for content navigation. Visual bindings are included in ? help.
- w/e advance to the next cell and b goes to the previous cell, wrapping just like
  Tab/Shift-Tab. These aliases are removed with the other cell-motion maps when
  entering content navigation, restoring native word motions.
- Titles are Edit Table, Edit Table (content), and Edit Cell. The default cell
  width is doubled from 32 to 64 columns. Single-line cells start one line high;
  decoded multiline cells start at their line count, capped at 10. Buffer-change
  callbacks grow/shrink and recenter the cell float up to 10 lines, including
  changes from typing, undo/redo, and API edits. Terminal bounds still take priority.

## Cell dismissal and keymap help follow-up

- Cell dismissal always accepts: Ctrl-s/Esc in Normal or Insert mode, Normal-mode
  Enter, and external cell-window closure all stage the cell contents as one table
  operation. The edited cell is fixed when its float opens, independent of later
  preview cursor movement. Undo reverts an accidental edit. Direct source-cell
  dismissal commits to the source or promotes a conflict to the full editor.
  Acceptance-on-dismissal can become configurable later; no public config is added.
  This does not change table-level transaction cancellation: q still discards all
  staged edits. These decisions supersede earlier cell-cancellation descriptions.
- Ctrl-y joins s as a Normal-mode table save-and-close key, with unchanged conflict
  checks and undo semantics. In the cell float, Enter and Ctrl-y confirm from both
  Normal and Insert mode (Ctrl-s/Esc remain acceptance aliases). Shift-Enter and
  Ctrl-j insert physical newlines without confirming; Ctrl-j is the portable fallback
  for terminals that cannot distinguish Shift-Enter. Nonrecursive mappings use native
  newline insertion rather than triggering the Enter confirmation mapping.
- Help titles are Table Editor Keymaps (cell navigation) and Table Editor Keymaps
  (content navigation). Remove the repeated heading from the body, align ordinary
  key names in a ten-character column, and highlight keys using MarkdownTableKey
  (default link Special). The desired help width is 1.5 times the padded content
  width, still bounded by the terminal. The footer is ?/q/Esc: close.

## Code review after initial dogfooding

### Cleanup and correctness fixes

- Split float layout/creation, mapping helpers, and keymap rendering into
  lua/markdown/table_view.lua. Keep parsing/rendering in table.lua, session/actions
  in table_editor.lua, and branching history in table_history.lua. The session
  factory is still substantial; extract pure mutation operations before another
  major expansion rather than introducing a framework now.
- Keep immutable source ranges/cursor metadata out of history snapshots, avoid a
  redundant deletion snapshot, reuse parsed context for direct source mutations,
  and share action metadata instead of reallocating it on each keystroke.
- Use separator-row source coordinates when selecting a column on that row. Source
  navigation visits real cells in ragged rows instead of falling back to column 0
  for nonexistent trailing cells; vertical movement clamps to a real target cell.
- Preserve original inline Markdown when decoded cell contents are unchanged. Such
  dismissal creates no history entry and does not format a direct source buffer.
- Remove per-character growing-prefix width measurements from ordinary rendering.
  Expand tabs before measuring unwrapped character widths so wrap/list/showbreak
  options cannot change Markdown padding.
- The parser can detach body rows into ERROR when a table ends with an empty row.
  Recover adjacent outer-pipe rows within error spans, anchored to a recognized
  header/separator and exact container prefix. Reject recovery nodes that swallow
  unrelated material before their header. Do not cross blank lines or code fences.
  This is bounded recovery for observed parser behavior, not a separate GFM parser.

### Remaining gaps, other than configuration

1. **Vim editing consistency:** counts are not generally supported (motions,
   yanks, pastes, column/cell deletion); dot repeats deletions only, not cell edits,
   insertion, paste, or alignment. Native characterwise yanks do not populate the
   editor's typed paste register. Content navigation retains table-action bindings
   such as i, s, yy, and p, so it is intentionally not an unrestricted Vim buffer.
2. **Clipboard/interchange:** typed registers are session-local, not named Vim
   registers or cross-table clipboards. No rectangular selection, multi-column
   selection, TSV import/paste, or table-aware direct-source cell paste exists.
   Source yank_cell produces decoded text: native p may insert physical newlines
   into a pipe row rather than replacing a cell safely.
3. **Recovery/session ergonomics:** whole-buffer changedtick checking rejects even
   unrelated edits (including edits later undone). Export is available, but there
   is no table-only conflict resolution, persistent draft, or session restoration.
   One active editor is allowed globally, not one per tab/buffer. Transaction-wide
   q cancellation still discards without a prompt, by deliberate agreement.
4. **Creation context:** new tables do not inherit list/quote prefixes or detect
   that the insertion point is inside a fence/HTML block. Existing nested tables
   work; creating a correctly nested table needs more context-aware insertion.
5. **Navigation polish:** no accept-and-advance cell action or pinned header when
   scrolling. Cell preview uses raw Markdown, and custom float filetypes do not
   automatically provide Markdown syntax highlighting. Wide/multiline content
   still requires scrolling; e and w intentionally both advance to the next cell.
6. **Scale and parser edge cases:** history stores full editable-table snapshots
   with no size cap; edits rerender the full table, and navigation reparses/collects
   document tables. Large data tables need profiling/caching/delta history before
   claiming spreadsheet-scale support. Malformed Markdown may still exceed the
   bounded parser-recovery cases covered by regression tests.
7. **Validation beyond headless tests:** real terminal/mouse/tmux behavior, unusual
   FileType/autocmd interactions, Windows UI behavior, and long-session stress are
   not established by the portable-version headless runs. Manual dogfooding still
   matters, especially direct-source actions and session/window lifecycle edges.

Suggested order: dogfood direct actions; resolve typed/native paste and counts/dot
semantics; improve creation context and conflict handling. Defer more features until
those interactions settle. Sorting/minification/live updates remain intentional
scope decisions, not regressions in the current implementation.

## Validation plan

Regression specs cover alignment, widths, Unicode, escaped pipes, uneven rows,
optional outer pipes, nested prefixes, cursor/range/all targeting, code exclusion,
idempotence, command registration, navigation, cell commit/cancel, insertions,
transaction commit/cancel, conflicts, undo, and float cleanup. Run the normal and
legacy parser suites; retain Neovim 0.10-compatible APIs.

First-implementation validation: 22 table-specific specs pass. The full suites pass on
Neovim 0.12.6 (normal and forced legacy, 291 tests each), 0.11.7 (290 tests), and
0.10.4 (289 tests). Older-version runs used temporary portable releases and isolated
XDG directories; counts differ because existing tests conditionally use newer APIs.
`git diff --check` passes. The 0.12 test bootstrap emits a non-fatal netrw packpath
warning; Plenary reports zero failures/errors in both suites.

Next-pass validation: 35 table specs pass, covering branching history, typed
copy/delete/paste, protected headers/last columns, alignment, new table creation,
content navigation and cursor synchronization, help/filetypes, resize centering,
Unicode horizontal scrolling, export after conflicts, direct source actions, and
source-cell conflict recovery. Full suites pass on Neovim 0.12.6 normal and forced
legacy (304 tests each), 0.11.7 (303), and 0.10.4 (302), using the same isolated
portable releases. `git diff --check` passes.

Float-interaction validation: 45 table specs pass, including mapped dot-repeat,
forward/backward Visual-line row ranges and grouped paste/undo, native characterwise
yanking, word-key aliases and mode switching, exact titles, centered growth/shrinkage
up to ten lines, and stale resize callbacks after closing/reopening a cell. Full
suites pass on Neovim 0.12.6 normal and forced legacy (314 tests each), 0.11.7 (313),
and 0.10.4 (312). `git diff --check` passes; changes remain unstaged.

Dismissal/help validation: 51 table specs pass, covering accepted Escape/external
closure, operation undo, edited-cell identity, direct-source dismissal and conflict
recovery, Ctrl-y save, help titles/columns/width/footer, and key highlights. Full
suites pass on Neovim 0.12.6 normal and forced legacy (320 tests each), 0.11.7 (319),
and 0.10.4 (318). `git diff --check` passes; changes remain unstaged.

Code-review validation: 64 table specs pass, including direct-source separator and
ragged-row targeting, source mutation/undo coverage, untouched-cell preservation,
smaller history snapshots, trailing-empty-row parser recovery, recovery boundaries,
and Unicode/tab alignment independent of window display options. Full suites pass
on Neovim 0.12.6 normal and forced legacy (333 tests each), 0.11.7 (332), and 0.10.4
(331). `git diff --check` passes; changes remain unstaged.
