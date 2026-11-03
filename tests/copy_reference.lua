-- Run from the config root: nvim --headless -u NONE -l tests/copy_reference.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.g.mapleader = " "
vim.o.clipboard = ""
vim.o.swapfile = false

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

local function pasted()
  return table.concat(clipboard[1], "\n")
end

local function keys(sequence)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
end

local cwd = vim.fn.getcwd()
local temp = vim.fn.tempname()
local ok, err = xpcall(function()
  vim.fn.mkdir(temp .. "/repo/.git", "p")
  vim.fn.mkdir(temp .. "/repo/src", "p")
  vim.cmd.cd(vim.fn.fnameescape(temp .. "/repo/src"))
  vim.cmd.edit(vim.fn.fnameescape(temp .. "/repo/src/example file.lua"))
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha beta", "second line", "third line", "```inside```" })
  dofile(cwd .. "/plugin/copy_reference.lua")
  vim.fn.setreg('"', "ordinary yank")
  vim.fn.setreg("0", "yank register")
  vim.fn.setreg("a", "named register")
  local unnamed = vim.fn.getreg('"')

  -- Commands use actual buffer line numbers and the Git root, not nested cwd.
  vim.cmd("2,3CopyReference")
  equal(pasted(), "src/example file.lua:2-3\n```lua\nsecond line\nthird line\n```")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd.CopyReference()
  equal(pasted(), "src/example file.lua:2\n```lua\nsecond line\n```")
  keys(" yr")
  equal(pasted(), "src/example file.lua:2\n```lua\nsecond line\n```")

  -- Characterwise, reversed, linewise, and blockwise visual selections.
  keys("gg0v4l yr")
  equal(pasted(), "src/example file.lua:1\n```lua\nalpha\n```")
  equal(vim.fn.mode(), "n")
  keys("gg04lv4h yr")
  equal(pasted(), "src/example file.lua:1\n```lua\nalpha\n```")
  keys("ggVj yr")
  equal(pasted(), "src/example file.lua:1-2\n```lua\nalpha beta\nsecond line\n```")
  keys("gg0<C-v>j2l yr")
  equal(pasted(), "src/example file.lua:1-2\n```lua\nalp\nsec\n```")
  vim.o.selection = "exclusive"
  keys("gg0v5l yr")
  equal(pasted(), "src/example file.lua:1\n```lua\nalpha\n```")
  vim.o.selection = "inclusive"

  -- UTF-8 and code containing Markdown fences.
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { "αβγ delta" })
  keys("gg0vl yr")
  equal(pasted(), "src/example file.lua:1\n```lua\nαβ\n```")
  vim.cmd("4CopyReference")
  equal(pasted(), "src/example file.lua:4\n````lua\n```inside```\n````")

  -- No normal-yank mapping or incidental writes to other registers.
  equal(vim.fn.maparg("y", "n"), "")
  equal(vim.fn.maparg("y", "x"), "")
  equal(vim.fn.getreg('"'), unnamed)
  equal(vim.fn.getreg("0"), "yank register")
  equal(vim.fn.getreg("a"), "named register")
  keys("ggyy")
  equal(vim.fn.getreg("0"), "αβγ delta\n")

  -- Non-Git files use cwd; unnamed/special buffers leave clipboard alone.
  vim.cmd.enew({ bang = true })
  vim.cmd.file(vim.fn.fnameescape(temp .. "/plain.txt"))
  vim.cmd.cd(vim.fn.fnameescape(temp))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
  vim.cmd.CopyReference()
  equal(pasted(), "plain.txt:1\n```\nplain text\n```")
  local previous = pasted()
  vim.cmd.enew({ bang = true })
  vim.cmd.CopyReference()
  equal(pasted(), previous)
  equal(notices[#notices][2], vim.log.levels.WARN)
  vim.cmd.file("special")
  vim.bo.buftype = "nofile"
  vim.cmd.CopyReference()
  equal(pasted(), previous)
end, debug.traceback)

vim.cmd.cd(vim.fn.fnameescape(cwd))
vim.fn.delete(temp, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("CopyReference tests passed")
vim.cmd("qa!")
