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
