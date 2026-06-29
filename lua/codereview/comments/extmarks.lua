local diffview = require("codereview.ui.diffview")

local M = {}
M.ns = vim.api.nvim_create_namespace("codereview-comments")
M.by_comment = {}

local COMMENT_WIDTH = 88

local function wrap_line(line, width)
  if line == "" then
    return { "" }
  end
  local out = {}
  local rest = line
  while #rest > width do
    local chunk = rest:sub(1, width)
    local split = chunk:match("^.*()%s+")
    if split and split > 12 then
      table.insert(out, vim.trim(rest:sub(1, split - 1)))
      rest = vim.trim(rest:sub(split + 1))
    else
      table.insert(out, chunk)
      rest = rest:sub(width + 1)
    end
  end
  table.insert(out, rest)
  return out
end

local function wrapped_text_lines(text, width)
  local lines = {}
  for line in ((text or "") .. "\n"):gmatch("([^\n]*)\n") do
    for _, wrapped in ipairs(wrap_line(line, width)) do
      table.insert(lines, wrapped)
    end
  end
  if #lines == 0 then
    table.insert(lines, "")
  end
  return lines
end

local function comment_lines(comment)
  local lines = {
    { { "-- Comment " .. comment.id .. " " .. string.rep("-", 36), "CodeReviewCommentHeader" } },
  }
  for _, line in ipairs(wrapped_text_lines(comment.comment_text, COMMENT_WIDTH)) do
    table.insert(lines, { { "   " .. line, "CodeReviewCommentBody" } })
  end
  table.insert(lines, { { string.rep("-", 50), "CodeReviewCommentHeader" } })
  return lines
end

local function clamp_line(buf, lnum)
  local line_count = math.max(vim.api.nvim_buf_line_count(buf), 1)
  lnum = tonumber(lnum) or 1
  if lnum < 1 then return 1 end
  if lnum > line_count then return line_count end
  return lnum
end

function M.create(buf, comment)
  local start_display = comment._display_start or diffview.real_to_display(comment.start_line)
  local end_display = comment._display_end or diffview.real_to_display(comment.end_line) or start_display
  if not start_display or start_display < 1 then
    vim.notify("CodeReview comment has no valid line: " .. tostring(comment.id), vim.log.levels.WARN)
    return nil
  end
  start_display = clamp_line(buf, start_display)
  end_display = clamp_line(buf, end_display)
  if end_display < start_display then
    end_display = start_display
  end
  local ids = {}
  ids.region = vim.api.nvim_buf_set_extmark(buf, M.ns, start_display - 1, 0, {
    end_row = end_display,
    hl_group = "CodeReviewAnnotatedRegion",
    hl_eol = true,
  })
  ids.sign = vim.api.nvim_buf_set_extmark(buf, M.ns, start_display - 1, 0, {
    sign_text = "●",
    sign_hl_group = "CodeReviewSign",
    number_hl_group = "CodeReviewSign",
    line_hl_group = "CodeReviewAnnotatedRegion",
  })
  ids.comment = comment
  ids.expanded = false
  ids.start_display = start_display
  ids.end_display = end_display
  M.by_comment[comment.id] = ids
  return ids
end

function M.toggle_expand(buf, comment_id)
  local ids = M.by_comment[comment_id]
  if not ids then return end
  local comment = ids.comment
  local display = clamp_line(buf, diffview.real_to_display(comment.end_line) or comment.end_line)
  if ids.virt then
    vim.api.nvim_buf_del_extmark(buf, M.ns, ids.virt)
    ids.virt = nil
    ids.expanded = false
  else
    local lines = comment_lines(comment)
    ids.virt = vim.api.nvim_buf_set_extmark(buf, M.ns, display - 1, 0, {
      virt_lines = lines,
      virt_lines_above = false,
    })
    ids.virt_line_count = #lines
    ids.expanded = true
  end
end

function M.any_expanded()
  for _, ids in pairs(M.by_comment) do
    if ids.expanded then
      return true
    end
  end
  return false
end

function M.set_all_expanded(buf, expanded)
  for id, ids in pairs(vim.deepcopy(M.by_comment)) do
    if M.by_comment[id] and M.by_comment[id].expanded ~= expanded then
      M.toggle_expand(buf, id)
    end
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
