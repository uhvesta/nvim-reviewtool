local queries = require("codereview.db.queries")
local Stack = require("codereview.undo.stack")

local M = {}
local stacks = {}

local function stack(session_id)
  stacks[session_id] = stacks[session_id] or Stack.new()
  return stacks[session_id]
end

local function apply(action, direction)
  if action.type == "add" then
    if direction == "undo" then
      queries.soft_delete_comment(action.comment_id)
    else
      queries.restore_comment(action.comment_id)
    end
  elseif action.type == "delete" then
    if direction == "undo" then
      queries.restore_comment(action.comment_id)
    else
      queries.soft_delete_comment(action.comment_id)
    end
  elseif action.type == "edit" then
    local src = direction == "undo" and action.before or action.after
    if src then
      queries.update_comment(action.comment_id, { comment_text = src.comment_text })
    end
  end
end

function M.get(session_id)
  return stack(session_id)
end

function M.push(session_id, action)
  stack(session_id):push(action)
end

function M.undo(session_id)
  return stack(session_id):undo(apply)
end

function M.redo(session_id)
  return stack(session_id):redo(apply)
end

return M
