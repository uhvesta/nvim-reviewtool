local config = require("codereview.config")
local highlights = require("codereview.diff.highlights")

local M = {}
M.current = nil

local function system(args)
  local out = vim.fn.systemlist(args)
  return vim.v.shell_error, out
end

local function read_file(path)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  return vim.fn.readfile(path)
end

local function git_show(repo, ref, path)
  if not ref or ref == "WORKING_TREE" or path == nil then
    return {}
  end
  local code, out = system({ "git", "-C", repo, "show", ref .. ":" .. path })
  if code ~= 0 then
    return {}
  end
  return out
end

local function full_new_content(session, file)
  if session.target_ref ~= "WORKING_TREE" then
    return git_show(session.repo_dir, session.target_ref, file.path)
  end
  return read_file(session.repo_dir .. "/" .. file.path)
end

local function ft_for(path)
  return vim.filetype.match({ filename = path }) or ""
end

local function make_buf(name, lines, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, #lines > 0 and lines or { "" })
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].filetype = ft
  pcall(vim.treesitter.start, buf, ft)
  return buf
end

local function build_from_hunks(file)
  local old_lines, new_lines = {}, {}
  local old_d2r, new_d2r, old_r2d, new_r2d = {}, {}, {}, {}
  local old_hl, new_hl = {}, {}

  for _, hunk in ipairs(file.hunks or {}) do
    for _, line in ipairs(hunk.lines or {}) do
      local display = #old_lines + 1
      if line.type == "context" then
        table.insert(old_lines, line.text)
        table.insert(new_lines, line.text)
        old_d2r[display], new_d2r[display] = line.old_lnum, line.new_lnum
        old_r2d[line.old_lnum], new_r2d[line.new_lnum] = display, display
      elseif line.type == "remove" then
        table.insert(old_lines, line.text)
        table.insert(new_lines, "")
        old_d2r[display], new_d2r[display] = line.old_lnum, nil
        old_r2d[line.old_lnum] = display
        old_hl[display] = "CodeReviewRemoved"
        new_hl[display] = "CodeReviewFiller"
      elseif line.type == "add" then
        table.insert(old_lines, "")
        table.insert(new_lines, line.text)
        old_d2r[display], new_d2r[display] = nil, line.new_lnum
        new_r2d[line.new_lnum] = display
        old_hl[display] = "CodeReviewFiller"
        new_hl[display] = "CodeReviewAdded"
      end
    end
  end

  return {
    old_lines = old_lines,
    new_lines = new_lines,
    old_display_to_real = old_d2r,
    new_display_to_real = new_d2r,
    old_real_to_display = old_r2d,
    new_real_to_display = new_r2d,
    old_hl = old_hl,
    new_hl = new_hl,
  }
end

local function build_full(old_content, new_content)
  local max = math.max(#old_content, #new_content, 1)
  local old_lines, new_lines = {}, {}
  local old_d2r, new_d2r, old_r2d, new_r2d = {}, {}, {}, {}
  for i = 1, max do
    old_lines[i] = old_content[i] or ""
    new_lines[i] = new_content[i] or ""
    if old_content[i] ~= nil then old_d2r[i], old_r2d[i] = i, i end
    if new_content[i] ~= nil then new_d2r[i], new_r2d[i] = i, i end
  end
  return {
    old_lines = old_lines,
    new_lines = new_lines,
    old_display_to_real = old_d2r,
    new_display_to_real = new_d2r,
    old_real_to_display = old_r2d,
    new_real_to_display = new_r2d,
    old_hl = {},
    new_hl = {},
  }
end

local function apply_line_highlights(buf, map)
  highlights.clear(buf)
  for lnum, group in pairs(map) do
    highlights.line(buf, lnum, group)
  end
end

function M.open(session, file)
  local ft = ft_for(file.path)
  local old_path = file.old_path or file.path
  local old_content = file.status == "added" and {} or git_show(session.repo_dir, session.base_ref, old_path)
  local new_content = file.status == "deleted" and {} or full_new_content(session, file)
  local aligned
  if file.binary then
    aligned = build_full({ "Binary file in base: " .. old_path }, { "Binary file in target: " .. file.path })
  elseif file.hunks and #file.hunks > 0 then
    aligned = build_from_hunks(file)
  else
    aligned = build_full(old_content, new_content)
  end

  local old_buf = make_buf("codereview://old/" .. old_path, aligned.old_lines, ft)
  local new_buf = make_buf("codereview://new/" .. file.path, aligned.new_lines, ft)
  vim.b[new_buf].codereview_side = "new"
  vim.b[new_buf].codereview_file = file.path

  vim.cmd("rightbelow vertical new")
  local old_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(old_win, old_buf)
  vim.cmd("vertical new")
  local new_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(new_win, new_buf)
  vim.api.nvim_set_current_win(new_win)

  for _, win in ipairs({ old_win, new_win }) do
    vim.wo[win].scrollbind = true
    vim.wo[win].cursorbind = true
    vim.wo[win].wrap = false
    vim.wo[win].signcolumn = "yes"
  end
  vim.cmd("syncbind")

  apply_line_highlights(old_buf, aligned.old_hl)
  apply_line_highlights(new_buf, aligned.new_hl)

  M.current = {
    session = session,
    file = file,
    old_buf = old_buf,
    new_buf = new_buf,
    old_win = old_win,
    new_win = new_win,
    maps = aligned,
    enable_lsp = config.get().enable_lsp,
  }
  return M.current
end

function M.display_to_real(display_lnum)
  if not M.current then return nil end
  return M.current.maps.new_display_to_real[display_lnum]
end

function M.real_to_display(real_lnum)
  if not M.current then return nil end
  return M.current.maps.new_real_to_display[real_lnum]
end

return M
