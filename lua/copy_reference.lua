local reference = require("code_reference")
local M = {}

local function copy(snapshot, err)
  if snapshot then
    local ok
    ok, err = reference.write_clipboard(reference.format(snapshot))
    if ok then
      vim.notify("Copied " .. reference.location(snapshot), vim.log.levels.INFO, { title = "CopyReference" })
      return
    end
  end
  vim.notify(err, vim.log.levels.WARN, { title = "CopyReference" })
end

function M.copy_lines(first, last)
  copy(reference.capture_lines(first, last))
end

function M.copy_visual()
  copy(reference.capture_visual())
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
