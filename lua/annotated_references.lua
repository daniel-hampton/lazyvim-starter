local reference = require("code_reference")
local M = {}
local sessions = {}
local namespace = vim.api.nvim_create_namespace("annotated_references")

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "References" })
end

local function valid(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function current_session(create)
  local root = vim.b.references_root or reference.project_root()
  if not sessions[root] and create then
    sessions[root] = { root = root, entries = {}, next_id = 1, version = 0 }
  end
  return sessions[root], root
end

local function scratch(session, kind, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "references://" .. kind .. session.root)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.b[buf].references_root = session.root
  vim.bo[buf].filetype = filetype
  return buf
end

local function close_window()
  local ok = pcall(vim.api.nvim_win_close, 0, true)
  if not ok then
    vim.cmd.enew()
  end
end

local function show(buf, vertical)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage() then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.cmd(vertical and "botright vsplit" or "botright 12split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.wrap = true
end

local function remove_marker(entry)
  if valid(entry.marker_buf) and entry.marker then
    pcall(vim.api.nvim_buf_del_extmark, entry.marker_buf, namespace, entry.marker)
  end
  entry.marker, entry.marker_buf = nil, nil
end

local function attach_marker(entry, buf)
  if not vim.api.nvim_buf_is_loaded(buf) or vim.api.nvim_buf_get_name(buf) ~= entry.filename then
    return
  end
  if entry.marker_buf == buf and entry.marker then
    if #vim.api.nvim_buf_get_extmark_by_id(buf, namespace, entry.marker, {}) > 0 then
      return
    end
  end
  remove_marker(entry)
  local row = math.min(entry.first - 1, vim.api.nvim_buf_line_count(buf) - 1)
  entry.marker = vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
    sign_text = "◆",
    sign_hl_group = "DiagnosticInfo",
    priority = 50,
  })
  entry.marker_buf = buf
end

local function render_collection(session)
  local sections = {}
  for index, entry in ipairs(session.entries) do
    sections[#sections + 1] = "## Reference "
      .. index
      .. "\n"
      .. reference.format(entry)
      .. "\n\n**Comment:**\n"
      .. entry.comment
  end
  return table.concat(sections, "\n\n---\n\n")
end

local function refresh_review(session)
  if not valid(session.review_buf) then
    return
  end
  local lines = {
    "References — " .. session.root,
    "Enter: source | e: edit | dd: remove | p: draft | y: copy | r: rebuild | X: clear | q: close",
    "",
  }
  session.review_rows = {}
  for _, entry in ipairs(session.entries) do
    lines[#lines + 1] = "#"
      .. entry.id
      .. "  "
      .. reference.location(entry)
      .. "  — "
      .. (entry.comment:match("[^\n]+") or "")
    session.review_rows[#lines] = entry
  end
  if #session.entries == 0 then
    lines[#lines + 1] = "No references yet. Select code and use <leader>ya to add one."
  end
  vim.bo[session.review_buf].modifiable = true
  vim.api.nvim_buf_set_lines(session.review_buf, 0, -1, false, lines)
  vim.bo[session.review_buf].modified = false
  vim.bo[session.review_buf].modifiable = false
end

local function changed(session)
  session.version = session.version + 1
  refresh_review(session)
end

local function comment_editor(session, snapshot, editing)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "references://comment/" .. buf)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.b[buf].references_root = session.root
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(editing and snapshot.comment or "", "\n", { plain = true }))
  vim.bo[buf].modified = false
  local saved = editing
  local width = math.max(1, math.min(90, vim.o.columns - 4))
  local height = math.max(1, math.min(12, vim.o.lines - 4))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Comment: " .. reference.location(snapshot) .. " ",
    title_pos = "center",
    footer = " :w save | :wq save/close | :q! discard | Ctrl-S save/close ",
    footer_pos = "center",
  })
  vim.wo[win].wrap = true

  local function cancel()
    vim.cmd.stopinsert()
    if valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  local function save()
    local comment = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if not comment:match("%S") then
      return nil, "Write a comment, or cancel with Ctrl-C / :q!"
    end
    if sessions[session.root] ~= session or (saved and not vim.tbl_contains(session.entries, snapshot)) then
      return nil, "This reference or collection was removed; comment not saved"
    end
    snapshot.comment = comment
    local updating = saved
    if not saved then
      snapshot.id = session.next_id
      session.next_id = session.next_id + 1
      session.entries[#session.entries + 1] = snapshot
      saved = true
      if valid(snapshot.bufnr) then
        attach_marker(snapshot, snapshot.bufnr)
      end
    end
    changed(session)
    vim.bo[buf].modified = false
    notify((updating and "Updated " or "Added ") .. reference.location(snapshot))
    return true
  end

  -- acwrite handles native :w/:wq without writing a file. Errors must abort :wq.
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local ok, err = save()
      if not ok then
        error(err, 0)
      end
    end,
  })
  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    local ok, err = save()
    if ok then
      cancel()
    else
      notify(err, vim.log.levels.WARN)
    end
  end, { buffer = buf, desc = "Save and close reference comment" })
  vim.keymap.set({ "n", "i" }, "<C-c>", cancel, { buffer = buf, desc = "Cancel reference comment" })
  -- Keep standard Normal/Insert/Visual editing, including Esc, in this buffer.
  vim.cmd.stopinsert()
end

local function add(snapshot, err)
  if not snapshot then
    notify(err, vim.log.levels.WARN)
    return
  end
  local session = sessions[snapshot.root]
  if not session then
    session = { root = snapshot.root, entries = {}, next_id = 1, version = 0 }
    sessions[snapshot.root] = session
  end
  comment_editor(session, snapshot, false)
end

function M.add_lines(first, last)
  add(reference.capture_lines(first, last))
end

function M.add_visual()
  add(reference.capture_visual())
end

local function jump(entry)
  local buf = vim.fn.bufnr(entry.filename)
  if (buf == -1 or not vim.api.nvim_buf_is_loaded(buf)) and vim.fn.filereadable(entry.filename) ~= 1 then
    notify("Source file is no longer available: " .. entry.filename, vim.log.levels.WARN)
    return
  end
  if buf == -1 then
    buf = vim.fn.bufadd(entry.filename)
  end
  local ok, err = pcall(vim.fn.bufload, buf)
  if not ok then
    notify("Could not open source: " .. tostring(err), vim.log.levels.WARN)
    return
  end
  attach_marker(entry, buf)
  local position = vim.api.nvim_buf_get_extmark_by_id(buf, namespace, entry.marker, {})
  local row = position[1] or entry.first - 1
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, { math.min(row + 1, vim.api.nvim_buf_line_count(buf)), 0 })
end

function M.review()
  local session = current_session(true)
  if not valid(session.review_buf) then
    session.review_buf = scratch(session, "review", "markdown")
    local function selected(action)
      local entry = session.review_rows[vim.api.nvim_win_get_cursor(0)[1]]
      if entry then
        action(entry)
      end
    end
    local mappings = {
      {
        "<CR>",
        function()
          selected(jump)
        end,
        "Jump to source",
      },
      {
        "e",
        function()
          selected(function(entry)
            comment_editor(session, entry, true)
          end)
        end,
        "Edit comment",
      },
      {
        "dd",
        function()
          selected(function(entry)
            remove_marker(entry)
            for index, candidate in ipairs(session.entries) do
              if candidate == entry then
                table.remove(session.entries, index)
                break
              end
            end
            changed(session)
          end)
        end,
        "Remove reference",
      },
      { "p", M.prepare, "Prepare message" },
      { "y", M.copy, "Copy message" },
      { "r", M.rebuild, "Rebuild message" },
      { "X", M.clear, "Clear collection and draft" },
      { "q", close_window, "Close review" },
    }
    for _, mapping in ipairs(mappings) do
      vim.keymap.set("n", mapping[1], mapping[2], { buffer = session.review_buf, desc = mapping[3] })
    end
  end
  refresh_review(session)
  show(session.review_buf, false)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
end

local function build_draft(session)
  if not valid(session.draft_buf) then
    session.draft_buf = scratch(session, "draft", "markdown")
    vim.keymap.set("n", "q", close_window, { buffer = session.draft_buf, desc = "Hide message draft" })
    vim.keymap.set("n", "gY", M.copy, { buffer = session.draft_buf, desc = "Copy message" })
    vim.keymap.set("n", "gR", M.rebuild, { buffer = session.draft_buf, desc = "Rebuild message" })
  end
  local text = render_collection(session)
  vim.api.nvim_buf_set_lines(session.draft_buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[session.draft_buf].modified = false
  session.draft_version = session.version
  session.generated_text = text
end

local function ensure_draft(session)
  if not session then
    notify("No references in this project yet", vim.log.levels.WARN)
    return false
  end
  if not valid(session.draft_buf) then
    if #session.entries == 0 then
      notify("No references in this project yet", vim.log.levels.WARN)
      return false
    end
    build_draft(session)
  elseif session.draft_version ~= session.version then
    notify("Collection changed; keeping your existing draft. Use :ReferencesRebuild to update it", vim.log.levels.WARN)
  end
  return true
end

function M.prepare()
  local session = current_session()
  if ensure_draft(session) then
    show(session.draft_buf, true)
    notify("Edit this Markdown message freely. <leader>yc or gY copies all; q hides the draft")
  end
end

function M.copy()
  local session = current_session()
  if not ensure_draft(session) then
    return
  end
  local text = table.concat(vim.api.nvim_buf_get_lines(session.draft_buf, 0, -1, false), "\n")
  if not text:match("%S") then
    notify("The draft is empty; clipboard unchanged", vim.log.levels.WARN)
    return
  end
  local ok, err = reference.write_clipboard(text)
  if not ok then
    notify(err, vim.log.levels.WARN)
    return
  end
  notify("Copied message; collection and draft retained")
end

function M.rebuild()
  local session = current_session()
  if not session or (#session.entries == 0 and not valid(session.draft_buf)) then
    notify("No references in this project yet", vim.log.levels.WARN)
    return
  end
  local function rebuild()
    if sessions[session.root] == session then
      build_draft(session)
      show(session.draft_buf, true)
      notify("Rebuilt message from the collection")
    end
  end
  -- 'modified' can reset when a nofile buffer is hidden; compare content instead.
  local edited = valid(session.draft_buf)
    and table.concat(vim.api.nvim_buf_get_lines(session.draft_buf, 0, -1, false), "\n") ~= session.generated_text
  if edited then
    vim.ui.select(
      { "Cancel", "Replace edited draft" },
      { prompt = "Rebuild discards your manual draft edits:" },
      function(choice)
        if choice == "Replace edited draft" then
          rebuild()
        end
      end
    )
  else
    rebuild()
  end
end

function M.clear()
  local session = current_session()
  if not session then
    notify("No collection to clear")
    return
  end
  vim.ui.select(
    { "Cancel", "Clear collection and draft" },
    { prompt = "Clear this project's references and draft?" },
    function(choice)
      if choice ~= "Clear collection and draft" or sessions[session.root] ~= session then
        return
      end
      for _, entry in ipairs(session.entries) do
        remove_marker(entry)
      end
      sessions[session.root] = nil
      for _, buf in ipairs({ session.review_buf or -1, session.draft_buf or -1 }) do
        if valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      notify("Cleared collection and draft")
    end
  )
end

function M.setup()
  local commands = {
    ReferencesReview = M.review,
    ReferencesDraft = M.prepare,
    ReferencesCopy = M.copy,
    ReferencesRebuild = M.rebuild,
    ReferencesClear = M.clear,
  }
  vim.api.nvim_create_user_command("ReferencesAdd", function(opts)
    M.add_lines(opts.line1, opts.line2)
  end, { range = true, desc = "Attach a comment to a code snapshot" })
  for name, action in pairs(commands) do
    vim.api.nvim_create_user_command(name, action, { desc = name:gsub("References", "References: ") })
  end
  vim.keymap.set("n", "<leader>ya", function()
    M.add_lines()
  end, { desc = "Add annotated reference" })
  vim.keymap.set("x", "<leader>ya", M.add_visual, { desc = "Add annotated reference" })
  vim.keymap.set("n", "<leader>yl", M.review, { desc = "List annotated references" })
  vim.keymap.set("n", "<leader>yp", M.prepare, { desc = "Prepare references message" })
  vim.keymap.set("n", "<leader>yc", M.copy, { desc = "Copy references message" })

  local group = vim.api.nvim_create_augroup("AnnotatedReferences", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter", "BufFilePost" }, {
    group = group,
    callback = function(event)
      for _, session in pairs(sessions) do
        for _, entry in ipairs(session.entries) do
          if entry.marker_buf == event.buf and vim.api.nvim_buf_get_name(event.buf) ~= entry.filename then
            remove_marker(entry)
          end
          attach_marker(entry, event.buf)
        end
      end
    end,
  })
end

return M
