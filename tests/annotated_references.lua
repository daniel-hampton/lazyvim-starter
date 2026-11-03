-- Run from the config root: nvim --headless -u NONE -l tests/annotated_references.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.g.mapleader = " "
vim.o.clipboard = ""
vim.o.swapfile = false
vim.o.hidden = true
vim.o.columns = 120
vim.o.lines = 40

local clipboard = { {}, "v" }
vim.g.clipboard = {
  name = "test clipboard",
  copy = {
    ["+"] = function(lines, regtype)
      clipboard = { lines, regtype }
    end,
    ["*"] = function() end,
  },
  paste = {
    ["+"] = function()
      return clipboard
    end,
    ["*"] = function()
      return { {}, "v" }
    end,
  },
  cache_enabled = 0,
}
local notices = {}
vim.notify = function(message, level)
  notices[#notices + 1] = { message, level }
end

local function equal(actual, expected)
  assert(vim.deep_equal(actual, expected), "Expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end
local function contains(text, expected)
  assert(text:find(expected, 1, true), "Missing " .. vim.inspect(expected) .. " in " .. vim.inspect(text))
end
local function keys(sequence)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
end
local function text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false), "\n")
end
local function pasted()
  return table.concat(clipboard[1], "\n")
end
local function comment(lines)
  equal(vim.api.nvim_win_get_config(0).relative, "editor")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  keys("<C-s>")
end
local function choose(answer)
  vim.ui.select = function(items, _, callback)
    assert(vim.tbl_contains(items, answer), "Unexpected confirmation: " .. vim.inspect(items))
    callback(answer)
  end
end
local ns = vim.api.nvim_create_namespace("annotated_references")
local function markers(buf)
  return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
end

local cwd = vim.fn.getcwd()
local temp = vim.fn.tempname()
local original_select = vim.ui.select
local original_has = vim.fn.has
local ok, err = xpcall(function()
  local root1, root2 = temp .. "/first", temp .. "/second"
  for _, root in ipairs({ root1, root2 }) do
    vim.fn.mkdir(root .. "/.git", "p")
    vim.fn.mkdir(root .. "/src", "p")
  end
  vim.fn.writefile({ "alpha beta", "second line", "third line", "```inside```", "λ unicode" }, root1 .. "/src/a.lua")
  vim.fn.writefile({ "one", "two", "three" }, root1 .. "/b.md")
  vim.fn.writefile({ "another project" }, root2 .. "/src/a.lua")
  dofile(cwd .. "/plugin/copy_reference.lua")
  dofile(cwd .. "/plugin/annotated_references.lua")

  -- Empty projects do not overwrite the clipboard; unnamed buffers cannot be added.
  vim.cmd.cd(vim.fn.fnameescape(root1 .. "/src"))
  vim.fn.setreg("+", "sentinel")
  vim.cmd.ReferencesCopy()
  equal(pasted(), "sentinel")
  vim.cmd.ReferencesAdd()
  equal(vim.api.nvim_win_get_config(0).relative, "")
  equal(notices[#notices][2], vim.log.levels.WARN)
  vim.cmd.edit(vim.fn.fnameescape(root1 .. "/src/a.lua"))
  local source1 = vim.api.nvim_get_current_buf()
  vim.bo.filetype = "lua"
  vim.fn.setreg("0", "ordinary yank")
  vim.fn.setreg("a", "named register")
  local unnamed = vim.fn.getreg('"')

  -- Collecting does not require a clipboard provider, only the final copy does.
  vim.fn.has = function(feature)
    return feature == "clipboard" and 0 or original_has(feature)
  end
  -- Visual add snapshots the exact selection before opening the multiline editor.
  keys("gg0v4l ya")
  comment({ "Please rename this.", "", "Keep the public behaviour." })
  equal(vim.api.nvim_get_current_buf(), source1)
  equal(#markers(source1), 1)
  equal(pasted(), "sentinel")
  local copied, clipboard_error = require("code_reference").write_clipboard("must not copy")
  equal(copied, nil)
  contains(clipboard_error, "No clipboard provider")
  equal(pasted(), "sentinel")
  vim.fn.has = original_has
  equal(vim.fn.getreg('"'), unnamed)
  equal(vim.fn.getreg("0"), "ordinary yank")
  equal(vim.fn.getreg("a"), "named register")
  equal(vim.fn.maparg("y", "n"), "")
  equal(vim.fn.maparg("y", "x"), "")

  -- Markers follow insertions, but captured text and original line numbers do not.
  vim.api.nvim_buf_set_lines(source1, 0, 0, false, { "new heading" })
  equal(markers(source1)[1][2], 1)
  vim.cmd.edit(vim.fn.fnameescape(root1 .. "/b.md"))
  local source_b = vim.api.nvim_get_current_buf()
  vim.bo.filetype = "markdown"
  vim.cmd("2,3ReferencesAdd")
  local canceled = vim.api.nvim_get_current_buf()
  keys("<Esc>")
  assert(not vim.api.nvim_buf_is_valid(canceled), "Canceled editor should be wiped")
  equal(#markers(source_b), 0)
  vim.cmd("2,3ReferencesAdd")
  comment({ "   " })
  equal(vim.api.nvim_win_get_config(0).relative, "editor")
  keys("<Esc>")
  vim.cmd("2,3ReferencesAdd")
  comment({ "Explain these lines.", "This is a separate reference." })
  equal(#markers(source_b), 1)

  vim.cmd.ReferencesReview()
  local review1 = vim.api.nvim_get_current_buf()
  contains(text(), "#1  src/a.lua:1")
  contains(text(), "#2  b.md:2-3")
  equal(vim.bo.modifiable, false)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  keys("<CR>")
  equal(vim.api.nvim_get_current_buf(), source1)
  equal(vim.fn.line("."), 2)
  vim.cmd.ReferencesReview()
  equal(vim.api.nvim_get_current_buf(), review1)
  keys("p")
  local draft1 = vim.api.nvim_get_current_buf()
  equal(vim.bo.buftype, "nofile")
  equal(vim.bo.bufhidden, "hide")
  equal(vim.bo.filetype, "markdown")
  equal(vim.bo.modified, false)
  equal(
    text(),
    "## Reference 1\nsrc/a.lua:1\n```lua\nalpha\n```\n\n**Comment:**\nPlease rename this.\n\nKeep the public behaviour."
      .. "\n\n---\n\n## Reference 2\nb.md:2-3\n```markdown\ntwo\nthree\n```\n\n**Comment:**\nExplain these lines.\nThis is a separate reference."
  )

  -- A draft is ordinary editable Markdown, and hiding/reopening it never regenerates it.
  vim.api.nvim_buf_set_lines(draft1, 0, 0, false, { "Please review this batch:", "" })
  local manual = text()
  keys("q")
  vim.api.nvim_set_current_buf(source1)
  vim.cmd.ReferencesDraft()
  equal(vim.api.nvim_get_current_buf(), draft1)
  equal(text(), manual)
  keys("gY")
  equal(pasted(), manual)
  equal(text(draft1), manual)
  equal(#markers(source1), 1)

  -- Adding or editing the collection must not silently change an existing draft.
  vim.api.nvim_set_current_buf(source1)
  vim.cmd("5ReferencesAdd")
  comment({ "A snippet containing Markdown fences." })
  keys("2G0<C-v>j2l ya")
  comment({ "Exact block selection." })
  equal(#markers(source1), 3)
  vim.cmd.ReferencesReview()
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  keys("e")
  contains(text(), "Please rename this.")
  comment({ "Updated first comment." })
  vim.api.nvim_win_set_cursor(0, { 5, 0 })
  keys("dd")
  equal(#markers(source_b), 0)
  assert(not text():find("b.md:2-3", 1, true))
  vim.cmd.ReferencesCopy()
  equal(pasted(), manual)
  equal(text(draft1), manual)
  contains(notices[#notices - 1][1], "Collection changed")

  choose("Cancel")
  vim.cmd.ReferencesRebuild()
  equal(text(draft1), manual)
  choose("Replace edited draft")
  vim.cmd.ReferencesRebuild()
  equal(vim.api.nvim_get_current_buf(), draft1)
  assert(not text():find("Please review this batch:", 1, true))
  assert(not text():find("b.md", 1, true))
  contains(text(), "src/a.lua:1\n```lua\nalpha\n```")
  contains(text(), "**Comment:**\nUpdated first comment.")
  contains(text(), "src/a.lua:5\n````lua\n```inside```\n````")
  contains(text(), "src/a.lua:2-3\n```lua\nalp\nsec\n```")
  equal(vim.bo.modified, false)
  keys("gY")
  equal(pasted(), text())
  local first_message = text()
  vim.ui.select = function()
    error("An unedited draft should rebuild without confirmation")
  end
  vim.cmd.ReferencesRebuild()
  equal(text(), first_message)

  -- A second project has independent entries, review, draft, and clipboard actions.
  vim.cmd.edit(vim.fn.fnameescape(root2 .. "/src/a.lua"))
  local source2 = vim.api.nvim_get_current_buf()
  vim.bo.filetype = "lua"
  vim.cmd.cd(vim.fn.fnameescape(root2))
  vim.cmd.ReferencesCopy()
  equal(pasted(), first_message)
  vim.cmd.ReferencesAdd()
  comment({ "Only for project two." })
  vim.cmd.ReferencesDraft()
  local draft2 = vim.api.nvim_get_current_buf()
  assert(draft1 ~= draft2)
  contains(text(), "another project")
  assert(not text():find("Updated first comment.", 1, true))
  vim.cmd.ReferencesCopy()
  local second_message = pasted()
  vim.api.nvim_set_current_buf(source1)
  vim.cmd.ReferencesDraft()
  equal(vim.api.nvim_get_current_buf(), draft1)
  equal(text(), first_message)
  vim.cmd.ReferencesCopy()
  equal(pasted(), first_message)

  -- Reopening a source restores its markers; missing files are handled without a crash.
  vim.api.nvim_buf_delete(source1, { force = true })
  vim.cmd.edit(vim.fn.fnameescape(root1 .. "/src/a.lua"))
  source1 = vim.api.nvim_get_current_buf()
  equal(#markers(source1), 3)
  equal(text(draft1), first_message)
  vim.api.nvim_set_current_buf(source2)
  vim.api.nvim_buf_delete(source2, { force = true })
  vim.fn.delete(root2 .. "/src/a.lua")
  vim.api.nvim_set_current_buf(draft2)
  vim.cmd.ReferencesReview()
  local review2 = vim.api.nvim_get_current_buf()
  keys("<CR>")
  equal(vim.api.nvim_get_current_buf(), review2)
  contains(notices[#notices][1], "no longer available")

  -- Clear is confirmed, project-scoped, and removes markers and both scratch buffers.
  vim.api.nvim_set_current_buf(draft1)
  choose("Cancel")
  vim.cmd.ReferencesClear()
  assert(vim.api.nvim_buf_is_valid(draft1))
  choose("Clear collection and draft")
  vim.cmd.ReferencesClear()
  assert(not vim.api.nvim_buf_is_valid(draft1))
  assert(not vim.api.nvim_buf_is_valid(review1))
  equal(#markers(source1), 0)
  assert(vim.api.nvim_buf_is_valid(draft2))
  vim.api.nvim_set_current_buf(draft2)
  vim.cmd.ReferencesCopy()
  equal(pasted(), second_message)

  -- A pending comment cannot resurrect a cleared collection.
  vim.cmd.edit(vim.fn.fnameescape(root2 .. "/pending.lua"))
  vim.cmd.ReferencesAdd()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Pending comment" })
  vim.cmd.ReferencesClear()
  keys("<C-s>")
  contains(notices[#notices][1], "not saved")
  vim.cmd.ReferencesReview()
  contains(text(), "No references yet")
  equal(pasted(), second_message)

  -- A modified draft rebuilt after deleting the last entry can be explicitly emptied.
  vim.cmd.edit(vim.fn.fnameescape(root2 .. "/last.lua"))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "last entry" })
  vim.cmd.ReferencesAdd()
  comment({ "Remove me." })
  vim.cmd.ReferencesDraft()
  local last_draft = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(0, 0, 0, false, { "Manual" })
  vim.cmd.ReferencesReview()
  keys("dd")
  choose("Replace edited draft")
  vim.cmd.ReferencesRebuild()
  equal(text(last_draft), "")
  vim.cmd.ReferencesCopy()
  equal(pasted(), second_message)
  contains(notices[#notices][1], "draft is empty")
end, debug.traceback)

vim.ui.select = original_select
vim.fn.has = original_has
vim.cmd.cd(vim.fn.fnameescape(cwd))
vim.fn.delete(temp, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("AnnotatedReferences tests passed")
vim.cmd("qa!")
