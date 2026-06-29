local queries = require("codereview.db.queries")
local diffview = require("codereview.ui.diffview")
local comment_float = require("codereview.ui.comment_float")
local extmarks = require("codereview.comments.extmarks")
local undo = require("codereview.undo")

local M = {}

local function visual_range()
  local mode = vim.fn.mode()
  local a, b
  if mode == "v" or mode == "V" or mode == "\22" then
    a = vim.fn.line("v")
    b = vim.fn.line(".")
  else
    a = vim.fn.getpos("'<")[2]
    b = vim.fn.getpos("'>")[2]
  end
  if a == 0 or b == 0 then
    local cursor = vim.api.nvim_win_get_cursor(0)[1]
    a, b = cursor, cursor
  end
  if a > b then a, b = b, a end
  return a, b
end

local function selected_real_lines(start_display, end_display)
  local lines = {}
  local start_real, end_real
  for display = start_display, end_display do
    if display < 1 then
      goto continue
    end
    local real = diffview.display_to_real(display)
    if real and real > 0 then
      start_real = start_real or real
      end_real = real
      table.insert(lines, vim.api.nvim_buf_get_lines(diffview.current.new_buf, display - 1, display, false)[1] or "")
    end
    ::continue::
  end
  return start_real, end_real, table.concat(lines, "\n")
end

function M.render_file_comments()
  if not diffview.current then return end
  extmarks.clear_all(diffview.current.new_buf)
  local comments = queries.get_comments(diffview.current.session.id, diffview.current.file.path)
  for _, comment in ipairs(comments) do
    if tonumber(comment.start_line) and tonumber(comment.start_line) > 0 then
      if extmarks.create(diffview.current.new_buf, comment) then
        extmarks.toggle_expand(diffview.current.new_buf, comment.id)
      end
    end
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
    comment._display_start = start_display
    comment._display_end = end_display
    extmarks.create(diffview.current.new_buf, comment)
    extmarks.toggle_expand(diffview.current.new_buf, comment.id)
    undo.push(diffview.current.session.id, { type = "add", comment_id = comment.id, after = comment })
    vim.notify("Saved CodeReview comment")
  end)
end

function M.list()
  if not diffview.current then return {} end
  return queries.get_comments(diffview.current.session.id)
end

local function invalid_comments_for_current_file()
  if not diffview.current then return {} end
  local rows = {}
  for _, comment in ipairs(queries.get_comments(diffview.current.session.id, diffview.current.file.path)) do
    if not tonumber(comment.start_line) or tonumber(comment.start_line) <= 0 then
      table.insert(rows, comment)
    end
  end
  return rows
end

function M.update_positions()
  if not diffview.current then return end
  for id, pos in pairs(extmarks.update_positions(diffview.current.new_buf)) do
    queries.update_comment(id, pos)
  end
end

function M.toggle_at_cursor()
  if not diffview.current then return end
  if not next(extmarks.by_comment) then
    local invalid = invalid_comments_for_current_file()
    if #invalid > 0 then
      vim.notify(
        #invalid .. " CodeReview comments have invalid saved line positions. Use <leader>cra to anchor one at the cursor.",
        vim.log.levels.WARN
      )
    else
      vim.notify("No CodeReview comments in current file", vim.log.levels.INFO)
    end
    return
  end
  local expand = extmarks.any_expanded()
  extmarks.set_all_expanded(diffview.current.new_buf, not expand)
  vim.notify((expand and "Collapsed" or "Expanded") .. " all CodeReview comments")
end

function M.anchor_invalid_at_cursor()
  if not diffview.current then return end
  if vim.b[vim.api.nvim_get_current_buf()].codereview_side ~= "new" then
    vim.notify("Move the cursor to the new side where the comment should attach", vim.log.levels.WARN)
    return
  end

  local display = vim.api.nvim_win_get_cursor(0)[1]
  local real = diffview.display_to_real(display)
  if not real or real <= 0 then
    vim.notify("Cursor is not on a commentable target line", vim.log.levels.WARN)
    return
  end

  local invalid = invalid_comments_for_current_file()
  if #invalid == 0 then
    vim.notify("No misplaced CodeReview comments to anchor in this file", vim.log.levels.INFO)
    return
  end

  vim.ui.select(invalid, {
    prompt = "Anchor misplaced CodeReview comment at cursor",
    format_item = function(comment)
      return "#" .. comment.id .. " " .. comment.comment_text:gsub("\n", " "):sub(1, 90)
    end,
  }, function(choice)
    if not choice then return end
    local line = vim.api.nvim_buf_get_lines(diffview.current.new_buf, display - 1, display, false)[1] or ""
    local updated = queries.update_comment(choice.id, {
      start_line = real,
      end_line = real,
      highlighted_text = line,
    })
    updated._display_start = display
    updated._display_end = display
    if extmarks.create(diffview.current.new_buf, updated) then
      extmarks.toggle_expand(diffview.current.new_buf, updated.id)
    end
    vim.notify("Anchored CodeReview comment #" .. updated.id .. " at line " .. real)
  end)
end

return M
