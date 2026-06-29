local source = require("codereview.source")
local queries = require("codereview.db.queries")
local layout = require("codereview.ui.layout")
local diffview = require("codereview.ui.diffview")
local comments = require("codereview.comments")

local M = {}
M.state = nil

local function close_view()
  if not diffview.current then return end
  for _, win in ipairs({ diffview.current.old_win, diffview.current.new_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  for _, buf in ipairs({ diffview.current.old_buf, diffview.current.new_buf }) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  diffview.current = nil
end

local function active_file()
  return M.state and M.state.files[M.state.current_index] or nil
end

local function reopen_current()
  if not M.state or #M.state.files == 0 then return end
  comments.update_positions()
  close_view()
  queries.update_session(M.state.session.id, { current_file_index = M.state.current_index })
  layout.refresh_sidebar(M.state, M.open_file, M.close)
  diffview.open(M.state.session, active_file())
  comments.render_file_comments()
end

local function create_name(src)
  local label = src.source_spec or src.source_type
  return label .. " @ " .. os.date("%Y-%m-%d %H:%M")
end

function M.create(spec)
  source.resolve(spec, function(src)
    if #src.file_list == 0 then
      vim.notify("No changed files found", vim.log.levels.INFO)
      return
    end
    local session = queries.create_session({
      name = create_name(src),
      source_type = src.source_type,
      source_spec = src.source_spec,
      repo_dir = src.repo_dir,
      base_ref = src.base_ref,
      target_ref = src.target_ref,
    })
    local files = {}
    for i, file in ipairs(src.file_list) do
      local saved = queries.add_file(session.id, {
        path = file.path,
        old_path = file.old_path,
        status = file.status,
        reviewed = 0,
        sort_order = i,
      })
      saved.hunks = file.hunks
      saved.binary = file.binary
      table.insert(files, saved)
    end
    M.state = { session = session, files = files, current_index = 1 }
    layout.open(M.state, M.open_file, M.close)
  end)
end

function M.resume(id)
  local session
  if id then
    session = queries.get_session(tonumber(id))
    if not session then
      vim.notify("No CodeReview session " .. id, vim.log.levels.ERROR)
      return
    end
    M.state = {
      session = session,
      files = queries.get_files(session.id),
      current_index = tonumber(session.current_file_index) or 1,
    }
    layout.open(M.state, M.open_file, M.close)
    return
  end
  local sessions = queries.list_sessions({ status = "active" })
  if #sessions == 0 then
    vim.notify("No active CodeReview sessions", vim.log.levels.INFO)
    return
  end
  vim.ui.select(sessions, {
    prompt = "Resume CodeReview session",
    format_item = function(s)
      return string.format("#%d %s (%s)", s.id, s.name, os.date("%Y-%m-%d %H:%M", tonumber(s.updated_at)))
    end,
  }, function(choice)
    if choice then M.resume(choice.id) end
  end)
end

function M.open_file(index)
  if not M.state or not M.state.files[index] then return end
  M.state.current_index = index
  reopen_current()
end

function M.next_file()
  if not M.state then return end
  M.open_file(math.min(#M.state.files, M.state.current_index + 1))
end

function M.prev_file()
  if not M.state then return end
  M.open_file(math.max(1, M.state.current_index - 1))
end

function M.mark_reviewed()
  local file = active_file()
  if not file then return end
  local reviewed = tonumber(file.reviewed) ~= 1
  queries.mark_file_reviewed(file.id, reviewed)
  file.reviewed = reviewed and 1 or 0
  layout.refresh_sidebar(M.state, M.open_file, M.close)
end

function M.current()
  return M.state
end

function M.close()
  if not M.state then return end
  comments.update_positions()
  queries.close_session(M.state.session.id)
  close_view()
  M.state = nil
  vim.notify("CodeReview session closed")
end

return M
