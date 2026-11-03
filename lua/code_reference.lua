-- Shared capture and rendering for single references and annotated collections.
local M = {}

function M.project_root(buf)
  buf = buf or 0
  local name = vim.api.nvim_buf_get_name(buf)
  local source = name ~= "" and vim.bo[buf].buftype == "" and name or vim.fn.getcwd()
  return vim.fs.normalize(vim.fs.root(source, ".git") or vim.fn.getcwd())
end

local function capture(lines, first, last)
  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" or vim.bo.buftype ~= "" then
    return nil, "Open a named file before capturing a reference"
  end
  local root = M.project_root()
  local prefix = root:gsub("/+$", "") .. "/"
  local path = vim.fs.normalize(filename)
  if path:sub(1, #prefix) == prefix then
    path = path:sub(#prefix + 1)
  end
  return {
    root = root,
    filename = filename,
    path = path,
    first = first,
    last = last,
    lines = lines,
    filetype = vim.bo.filetype,
    bufnr = vim.api.nvim_get_current_buf(),
  }
end

function M.capture_lines(first, last)
  first = first or vim.fn.line(".")
  last = last or first
  return capture(vim.api.nvim_buf_get_lines(0, first - 1, last, false), first, last)
end

function M.capture_visual()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return nil, "Select text in Visual mode first"
  end
  local start = vim.fn.getpos("v")
  local finish = vim.fn.getpos(".")
  local opts = { type = mode, exclusive = vim.o.selection == "exclusive" }
  local lines = vim.fn.getregion(start, finish, opts)
  local positions = vim.fn.getregionpos(start, finish, opts)
  local reference, err
  if #positions > 0 then
    reference, err = capture(lines, positions[1][1][2], positions[#positions][2][2])
  else
    err = "The selection is empty"
  end
  vim.cmd.normal({ args = { vim.api.nvim_replace_termcodes("<Esc>", true, false, true) }, bang = true })
  return reference, err
end

function M.location(reference)
  local location = reference.path .. ":" .. reference.first
  if reference.last ~= reference.first then
    location = location .. "-" .. reference.last
  end
  return location
end

function M.format(reference)
  local snippet = table.concat(reference.lines, "\n")
  -- A longer fence safely contains snippets that themselves include Markdown fences.
  local fence_length = 3
  for run in snippet:gmatch("`+") do
    fence_length = math.max(fence_length, #run + 1)
  end
  local fence = string.rep("`", fence_length)
  return M.location(reference) .. "\n" .. fence .. reference.filetype .. "\n" .. snippet .. "\n" .. fence
end

function M.write_clipboard(text)
  if vim.fn.has("clipboard") ~= 1 then
    return nil, "No clipboard provider available; see :help clipboard"
  end
  local ok, result = pcall(vim.fn.setreg, "+", text, "v")
  if not ok or result ~= 0 then
    return nil, "Could not write to clipboard: " .. tostring(result)
  end
  return true
end

return M
