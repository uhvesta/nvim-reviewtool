local diffview = require("codereview.ui.diffview")

local M = {}
M.ns = vim.api.nvim_create_namespace("codereview-comments")
M.by_comment = {}

local function comment_lines(comment)
  local lines = {
    { { "-- Comment " .. comment.id .. " " .. string.rep("-", 36), "CodeReviewCommentHeader" } },
  }
  for line in (comment.comment_text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, { { "   " .. line, "CodeReviewCommentBody" } })
  end
  table.insert(lines, { { string.rep("-", 50), "CodeReviewCommentHeader" } })
  return lines
end

function M.create(buf, comment)
  local start_display = diffview.real_to_display(comment.start_line) or comment.start_line
  local end_display = diffview.real_to_display(comment.end_line) or start_display
  local ids = {}
  ids.region = vim.api.nvim_buf_set_extmark(buf, M.ns, start_display - 1, 0, {
    end_row = end_display,
    hl_group = "CodeReviewAnnotatedRegion",
    hl_eol = true,
  })
  ids.sign = vim.api.nvim_buf_set_extmark(buf, M.ns, start_display - 1, 0, {
    sign_text = "●",
    sign_hl_group = "CodeReviewSign",
  })
  ids.comment = comment
  ids.expanded = false
  M.by_comment[comment.id] = ids
  return ids
end

function M.toggle_expand(buf, comment_id)
  local ids = M.by_comment[comment_id]
  if not ids then return end
  local comment = ids.comment
  local display = diffview.real_to_display(comment.end_line) or comment.end_line
  if ids.virt then
    vim.api.nvim_buf_del_extmark(buf, M.ns, ids.virt)
    ids.virt = nil
    ids.expanded = false
  else
    ids.virt = vim.api.nvim_buf_set_extmark(buf, M.ns, display - 1, 0, {
      virt_lines = comment_lines(comment),
      virt_lines_above = false,
    })
    ids.expanded = true
  end
end

function M.clear_all(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  end
  M.by_comment = {}
end

function M.update_positions(buf)
  local positions = {}
  for id, marks in pairs(M.by_comment) do
    local pos = vim.api.nvim_buf_get_extmark_by_id(buf, M.ns, marks.region, {})
    if pos and pos[1] then
      positions[id] = { start_line = diffview.display_to_real(pos[1] + 1) or (pos[1] + 1) }
    end
  end
  return positions
end

return M
