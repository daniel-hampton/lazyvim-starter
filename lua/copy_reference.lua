local M = {}

local function warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = "CopyReference" })
end

local function copy(lines, first, last)
  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" or vim.bo.buftype ~= "" then
    warn("Open a named file before copying a reference")
    return
  end
  if vim.fn.has("clipboard") ~= 1 then
    warn("No clipboard provider available; see :help clipboard")
    return
  end

  local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
  local prefix = vim.fs.normalize(root):gsub("/+$", "") .. "/"
  local path = vim.fs.normalize(filename)
  if path:sub(1, #prefix) == prefix then
    path = path:sub(#prefix + 1)
  end

  local location = path .. ":" .. first
  if last ~= first then
    location = location .. "-" .. last
  end
  local snippet = table.concat(lines, "\n")
  -- Keep Markdown snippets containing backticks inside a single fenced block.
  local fence_length = 3
  for run in snippet:gmatch("`+") do
    fence_length = math.max(fence_length, #run + 1)
  end
  local fence = string.rep("`", fence_length)
  local text = location .. "\n" .. fence .. vim.bo.filetype .. "\n" .. snippet .. "\n" .. fence
  local ok, err = pcall(vim.fn.setreg, "+", text, "v")
  if not ok then
    warn("Could not write to clipboard: " .. tostring(err))
    return
  end
  vim.notify("Copied " .. location, vim.log.levels.INFO, { title = "CopyReference" })
end

function M.copy_lines(first, last)
  first = first or vim.fn.line(".")
  last = last or first
  copy(vim.api.nvim_buf_get_lines(0, first - 1, last, false), first, last)
end

function M.copy_visual()
  local start = vim.fn.getpos("v")
  local finish = vim.fn.getpos(".")
  local opts = { type = vim.fn.mode(), exclusive = vim.o.selection == "exclusive" }
  local lines = vim.fn.getregion(start, finish, opts)
  local positions = vim.fn.getregionpos(start, finish, opts)
  if #positions > 0 then
    copy(lines, positions[1][1][2], positions[#positions][2][2])
  end
  vim.cmd.normal({ args = { vim.api.nvim_replace_termcodes("<Esc>", true, false, true) }, bang = true })
end

function M.setup()
  vim.api.nvim_create_user_command("CopyReference", function(opts)
    M.copy_lines(opts.line1, opts.line2)
  end, { range = true, desc = "Copy code with its relative path and line range" })

  vim.keymap.set("n", "<leader>yr", function()
    M.copy_lines()
  end, { desc = "Copy reference to clipboard" })
  vim.keymap.set("x", "<leader>yr", M.copy_visual, { desc = "Copy reference to clipboard" })
end

return M
