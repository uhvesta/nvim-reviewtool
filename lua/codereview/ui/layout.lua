local sidebar = require("codereview.ui.sidebar")
local diffview = require("codereview.ui.diffview")
local comments = require("codereview.comments")

local M = {}

function M.open(state, on_open, on_close)
  vim.cmd("tabnew")
  sidebar.render(state.session, state.files, state.current_index, on_open, on_close)
  local view = diffview.open(state.session, state.files[state.current_index])
  comments.render_file_comments()
  return view
end

function M.refresh_sidebar(state, on_open, on_close)
  sidebar.render(state.session, state.files, state.current_index, on_open, on_close)
end

return M
