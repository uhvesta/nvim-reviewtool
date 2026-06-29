local queries = require("codereview.db.queries")
local diffview = require("codereview.ui.diffview")
local comment_float = require("codereview.ui.comment_float")
local extmarks = require("codereview.comments.extmarks")
local undo = require("codereview.undo")

local M = {}

local function visual_range()
  local a = vim.fn.getpos("'<")[2]
  local b = vim.fn.getpos("'>")[2]
  if a > b then a, b = b, a end
  return a, b
end

local function selected_real_lines(start_display, end_display)
  local lines = {}
  local start_real, end_real
  for display = start_display, end_display do
    local real = diffview.display_to_real(display)
    if real then
      start_real = start_real or real
      end_real = real
      table.insert(lines, vim.api.nvim_buf_get_lines(diffview.current.new_buf, display - 1, display, false)[1] or "")
    end
  end
  return start_real, end_real, table.concat(lines, "\n")
end

function M.render_file_comments()
  if not diffview.current then return end
  extmarks.clear_all(diffview.current.new_buf)
  local comments = queries.get_comments(diffview.current.session.id, diffview.current.file.path)
  for _, comment in ipairs(comments) do
    extmarks.create(diffview.current.new_buf, comment)
  end
end

function M.add()
  if not diffview.current or vim.b[vim.api.nvim_get_current_buf()].codereview_side ~= "new" then
    vim.notify("Select lines on the new side of a CodeReview diff", vim.log.levels.WARN)
    return
  end
  local start_display, end_display = visual_range()
  local start_real, end_real, highlighted = selected_real_lines(start_display, end_display)
  if not start_real then
    vim.notify("Selection contains no changed target lines", vim.log.levels.WARN)
    return
  end
  comment_float.open(function(text)
    local comment = queries.create_comment({
      session_id = diffview.current.session.id,
      file_path = diffview.current.file.path,
      start_line = start_real,
      end_line = end_real,
      highlighted_text = highlighted,
      comment_text = text,
    })
    extmarks.create(diffview.current.new_buf, comment)
    undo.push(diffview.current.session.id, { type = "add", comment_id = comment.id, after = comment })
  end)
end

function M.list()
  if not diffview.current then return {} end
  return queries.get_comments(diffview.current.session.id)
end

function M.update_positions()
  if not diffview.current then return end
  for id, pos in pairs(extmarks.update_positions(diffview.current.new_buf)) do
    queries.update_comment(id, pos)
  end
end

function M.toggle_at_cursor()
  if not diffview.current then return end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  for id, marks in pairs(extmarks.by_comment) do
    local c = marks.comment
    local s = diffview.real_to_display(c.start_line) or c.start_line
    local e = diffview.real_to_display(c.end_line) or s
    if line >= s and line <= e then
      extmarks.toggle_expand(diffview.current.new_buf, id)
      return
    end
  end
end

return M
