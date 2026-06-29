local diffview = require("codereview.ui.diffview")
local comments = require("codereview.comments")

local M = {}

function M.open(state)
  vim.cmd("tabnew")
  local view = diffview.open(state.session, state.files[state.current_index])
  comments.render_file_comments()
  return view
end

function M.refresh()
end

return M
