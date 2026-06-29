local queries = require("codereview.db.queries")

local M = {}
M.buf = nil
M.win = nil
M.files = {}

local status_icon = {
  modified = "M",
  added = "A",
  deleted = "D",
  renamed = "R",
}

local status_hl = {
  modified = "CodeReviewFileModified",
  added = "CodeReviewFileAdded",
  deleted = "CodeReviewFileDeleted",
  renamed = "CodeReviewFileRenamed",
}

function M.render(session, files, current_index, on_open, on_close)
  M.files = files
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.buf].buftype = "nofile"
    vim.bo[M.buf].bufhidden = "wipe"
    vim.bo[M.buf].filetype = "codereview-sidebar"
  end
  if not M.win or not vim.api.nvim_win_is_valid(M.win) then
    vim.cmd("topleft 35vnew")
    M.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.win, M.buf)
    vim.wo[M.win].winfixwidth = true
  end

  local comment_counts = {}
  for _, c in ipairs(queries.get_comments(session.id)) do
    comment_counts[c.file_path] = (comment_counts[c.file_path] or 0) + 1
  end

  local lines = { " Code Review", " " .. string.rep("-", 32) }
  for i, file in ipairs(files) do
    local cursor = i == current_index and "▸" or " "
    local reviewed = tonumber(file.reviewed) == 1 and "✓" or " "
    local count = comment_counts[file.path] and (" [" .. comment_counts[file.path] .. "]") or ""
    local label = file.status == "renamed" and ((file.old_path or "") .. " -> " .. file.path) or file.path
    table.insert(lines, string.format("%s %s %s %s%s", cursor, status_icon[file.status] or "M", reviewed, label, count))
  end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(M.buf, -1, 0, -1)
  vim.api.nvim_buf_add_highlight(M.buf, -1, "CodeReviewSidebarTitle", 0, 1, -1)
  for i, file in ipairs(files) do
    vim.api.nvim_buf_add_highlight(M.buf, -1, status_hl[file.status] or "CodeReviewFileModified", i + 1, 2, 3)
    if tonumber(file.reviewed) == 1 then
      vim.api.nvim_buf_add_highlight(M.buf, -1, "CodeReviewReviewed", i + 1, 4, 7)
    end
  end
  vim.keymap.set("n", "<CR>", function()
    local idx = vim.api.nvim_win_get_cursor(0)[1] - 2
    if idx >= 1 and files[idx] then on_open(idx) end
  end, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "q", on_close, { buffer = M.buf, nowait = true })
end

return M
