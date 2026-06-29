local queries = require("codereview.db.queries")

local M = {}

function M.open(session, files)
  local comments = queries.get_comments(session.id)
  local reviewed = 0
  local counts = {}
  for _, file in ipairs(files) do
    if tonumber(file.reviewed) == 1 then reviewed = reviewed + 1 end
  end
  for _, c in ipairs(comments) do
    counts[c.file_path] = (counts[c.file_path] or 0) + 1
  end
  local lines = {
    "# Code Review Summary",
    "",
    "Session: " .. session.name,
    "Source: " .. session.source_type,
    "Files: " .. reviewed .. "/" .. #files .. " reviewed",
    "Comments: " .. #comments,
    "",
  }
  for _, file in ipairs(files) do
    table.insert(lines, string.format("- [%s] %s (%s comments)", tonumber(file.reviewed) == 1 and "x" or " ", file.path, counts[file.path] or 0))
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.min(90, math.floor(vim.o.columns * 0.75)),
    height = math.min(#lines + 2, math.floor(vim.o.lines * 0.75)),
    row = math.floor(vim.o.lines * 0.1),
    col = math.floor(vim.o.columns * 0.12),
    border = "rounded",
    style = "minimal",
    title = "CodeReview Summary",
  })
end

return M
