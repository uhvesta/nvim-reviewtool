local config = require("codereview.config")
local db = require("codereview.db")
local highlights = require("codereview.diff.highlights")
local session = require("codereview.session")
local comments = require("codereview.comments")
local clipboard = require("codereview.clipboard")
local undo = require("codereview.undo")
local summary = require("codereview.ui.summary")
local file_picker = require("codereview.telescope.file_picker")

local M = {}

local function require_session()
  local state = session.current()
  if not state then
    vim.notify("No active CodeReview session", vim.log.levels.WARN)
  end
  return state
end

function M.setup(opts)
  config.setup(opts)
  db.open()
  highlights.setup()
  require("codereview.keymaps").setup(M)
  require("codereview.session.startup").setup()
end

function M.new(source_spec)
  session.create(source_spec)
end

function M.resume(session_id)
  session.resume(session_id)
end

function M.next_file()
  session.next_file()
end

function M.prev_file()
  session.prev_file()
end

function M.add_comment()
  comments.add()
end

function M.toggle_comment()
  comments.toggle_at_cursor()
end

function M.anchor_comment()
  comments.anchor_invalid_at_cursor()
end

function M.delete_comment()
  comments.delete_picker()
end

function M.mark_reviewed()
  session.mark_reviewed()
end

function M.files()
  file_picker.open()
end

function M.dump(opts)
  opts = opts or {}
  local state = require_session()
  if not state then return end
  comments.update_positions()
  local text = clipboard.dump(state.session, {
    include_snippets = opts.no_snippets and false or config.get().include_snippets,
  })
  clipboard.to_clipboard(text)
  vim.notify("CodeReview comments copied to clipboard")
  return text
end

function M.summary()
  local state = require_session()
  if not state then return end
  summary.open(state.session, state.files)
end

function M.close()
  session.close()
end

function M.undo()
  local state = require_session()
  if not state then return end
  if undo.undo(state.session.id) then
    comments.render_file_comments()
  else
    vim.notify("Nothing to undo", vim.log.levels.INFO)
  end
end

function M.redo()
  local state = require_session()
  if not state then return end
  if undo.redo(state.session.id) then
    comments.render_file_comments()
  else
    vim.notify("Nothing to redo", vim.log.levels.INFO)
  end
end

function M.comments()
  local state = require_session()
  if not state then return end
  local rows = comments.list()
  if #rows == 0 then
    vim.notify("No CodeReview comments")
    return
  end
  vim.ui.select(rows, {
    prompt = "CodeReview comments",
    format_item = function(c)
      return string.format("%s:%d %s", c.file_path, c.start_line, c.comment_text:gsub("\n", " "))
    end,
  }, function() end)
end

return M
