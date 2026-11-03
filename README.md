# 💤 LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

## Copy a code reference

A local plugin copies code to the system clipboard with a relative filepath and
line range, ready to paste into an LLM conversation. Normal `y`/`yy` bindings are
unchanged.

- **Normal mode:** `<leader>yr` copies the current line.
- **Visual mode:** `<leader>yr` copies the selected text (character, line, or block).
- **Command:** `:CopyReference` copies the current line;
  `:12,18CopyReference` copies lines 12–18; `:%CopyReference` copies the whole file.

Example clipboard content:

````text
lua/config/keymaps.lua:12-18
```lua
-- selected code, without inline line numbers
```
````

Paths are relative to the file's nearest Git root, or the current working directory
for non-Git files. Files outside that directory retain their absolute path.
References describe the current buffer, including unsaved edits, so save first if
the recipient needs line numbers to match the file on disk. Unnamed and special
buffers are rejected.

Requires Neovim 0.11+ and a working clipboard provider (`:checkhealth vim.provider`).
Only the `+` register is written; your existing `clipboard` setting still controls
whether ordinary yanks share the system clipboard.

Implementation: `lua/copy_reference.lua`, loaded by `plugin/copy_reference.lua`.
Run the self-contained tests from this directory:

```sh
nvim --headless -u NONE -l tests/copy_reference.lua
```

## Collect annotated references

Build a batch of code snapshots with comments, then prepare a single editable
Markdown message for an LLM. This is separate from `<leader>yr` and normal yanks.

### Workflow

1. Select code in Visual mode and press **`<leader>ya`**. Characterwise, linewise,
   and blockwise selections are captured exactly. In Normal mode, the same mapping
   captures the current line.
2. Write a multiline comment in the floating editor. It opens in **Normal mode**
   and supports standard Vim motions and editing: use **`i`**, **`a`**, or **`o`**
   to enter Insert mode, and **Esc** to return to Normal mode without closing it.
   Use **`:w`** to save into the collection and keep editing, or **`:wq`** to save
   and close. **`:q`** closes if there are no unsaved edits; **`:q!`** discards
   unsaved edits. **Ctrl-S** saves and closes; **Ctrl-C** discards unsaved edits
   and closes (both shortcuts work in Normal and Insert modes). Saving never
   writes a file. After `:w`, canceling discards only subsequent edits, not the
   already-saved comment. Empty comments cannot be saved; a failed `:wq` leaves
   the editor open.
3. Repeat in the same file or other files in the project. A **◆ gutter marker**
   appears at the beginning of each annotated selection.
4. Press **`<leader>yl`** to review the collection. Use **Enter** to jump to the
   source, **`e`** to edit a comment, **`dd`** to remove an entry, and **`q`** to
   close the review window. The list also supports **`p`** (prepare draft), **`y`**
   (copy message), **`r`** (rebuild draft), and **`X`** (clear, with confirmation).
5. Press **`<leader>yp`** to prepare/open the Markdown draft. Edit it normally:
   add an introduction, reorder sections, trim snippets, or rewrite anything.
6. Press **`<leader>yc`** from the source, review, or draft to copy the **entire
   draft**. If no draft exists, one is generated first. The draft also supports
   **`gY`** to copy, **`gR`** to rebuild, and **`q`** to hide it.

Comments appear below their snippets, with numbered references separated by
horizontal rules:

````markdown
## Reference 1
lua/copy_reference.lua:1-2
```lua
local reference = require("code_reference")
local M = {}
```

**Comment:**
Could we rename this module?

---

## Reference 2
README.md:1
```markdown
# 💤 LazyVim
```

**Comment:**
Keep this heading unchanged.
````

### Collection versus draft

The collection stores snapshots and comments **in memory**, separately for each
Git project (or working directory outside Git). It lasts only for this Neovim
session; nothing is saved to disk or shared between Neovim instances. Collecting
and reviewing work without a clipboard provider; copying requires one.

The draft is an unlisted scratch Markdown buffer, not a temporary file. Hiding it
or switching files preserves its text. Commands issued from the review or draft
still operate on that buffer's project, even if the working directory changes.
Copying never clears the collection or changes the draft.

**Draft edits do not change the collection.** Adding, editing, or removing entries
does not silently regenerate an existing draft. Opening/copying an out-of-date
draft warns you and preserves it exactly. Use **`:ReferencesRebuild`** to render the
current collection again; replacing a manually edited draft requires confirmation.
Deleting/wiping the draft buffer yourself discards its manual edits; the next
prepare/copy regenerates it from the collection.

Use **`:ReferencesClear`** to clear the current project's collection, markers, review,
and draft. This always asks for confirmation. Other projects are unaffected.

Snapshots include unsaved buffer text. Their exported paths, line ranges, and code
stay as originally captured, even if the source changes. Gutter markers track line
movement while the source buffer remains loaded, and review jumps use that tracked
position. After unloading/reopening a file, markers fall back to the original line
number (clamped to the file length). They are navigation aids, not live references.

### Commands

| Command | Action |
| --- | --- |
| `:ReferencesAdd` | Comment on the current line |
| `:12,18ReferencesAdd` | Comment on a line range |
| `:ReferencesReview` | Open the collection review list |
| `:ReferencesDraft` | Prepare/open the editable message |
| `:ReferencesCopy` | Copy the whole draft, generating it if necessary |
| `:ReferencesRebuild` | Rebuild the draft from the collection |
| `:ReferencesClear` | Confirm clearing this project's collection and draft |

Use the Visual mapping for exact partial-line selections; a command range captures
whole lines. Unnamed and special buffers cannot be annotated.

Implementation: `lua/annotated_references.lua`, loaded by
`plugin/annotated_references.lua`. Both plugins share capture, Markdown formatting,
and clipboard support in `lua/code_reference.lua`.

Run both test suites from this directory:

```sh
nvim --headless -u NONE -l tests/copy_reference.lua
nvim --headless -u NONE -l tests/annotated_references.lua
```
