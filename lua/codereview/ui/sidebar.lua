local queries = require("codereview.db.queries")

local M = {}
M.buf = nil
M.win = nil
M.tree = nil
M.files = {}

local status_icon = {
  modified = "M",
  added = "A",
  deleted = "D",
  renamed = "R",
}

local status_hl = {
  modified = "CodeReviewFileModified",
  added = "CodeReviewFileAdded",
  deleted = "CodeReviewFileDeleted",
  renamed = "CodeReviewFileRenamed",
}

local function configure_window(win)
  vim.wo[win].winfixwidth = true
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].cursorline = true
  vim.wo[win].list = false
end

local function get_icon(path)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return " "
  end
  local icon, hl = devicons.get_icon(path, vim.fn.fnamemodify(path, ":e"), { default = true })
  return icon or " ", hl
end

local function split_path(path)
  return vim.split(path, "/", { plain = true, trimempty = true })
end

local function dir_key(parts, upto)
  local slice = {}
  for i = 1, upto do
    slice[i] = parts[i]
  end
  return table.concat(slice, "/")
end

local function build_tree_nodes(files, current_index, comment_counts)
  local ok_tree, NuiTree = pcall(require, "nui.tree")
  if not ok_tree then
    return nil
  end

  local dirs = {}
  local roots = {}

  local function ensure_dir(parts, depth)
    local key = dir_key(parts, depth)
    if dirs[key] then
      return dirs[key]
    end
    local node = NuiTree.Node({
      id = "dir:" .. key,
      kind = "dir",
      name = parts[depth],
      path = key,
    })
    node:expand()
    dirs[key] = node
    if depth == 1 then
      table.insert(roots, node)
    else
      local parent = ensure_dir(parts, depth - 1)
      parent.__children = parent.__children or {}
      table.insert(parent.__children, node)
    end
    return node
  end

  for i, file in ipairs(files) do
    local parts = split_path(file.path)
    local basename = parts[#parts] or file.path
    local file_node = NuiTree.Node({
      id = "file:" .. i,
      kind = "file",
      index = i,
      current = i == current_index,
      name = basename,
      path = file.path,
      file = file,
      count = comment_counts[file.path] or 0,
    })

    if #parts > 1 then
      local parent = ensure_dir(parts, #parts - 1)
      parent.__children = parent.__children or {}
      table.insert(parent.__children, file_node)
    else
      table.insert(roots, file_node)
    end
  end

  return roots, NuiTree
end

local function fallback_render(session, files, current_index, on_open, on_close)
  local comment_counts = {}
  for _, c in ipairs(queries.get_comments(session.id)) do
    comment_counts[c.file_path] = (comment_counts[c.file_path] or 0) + 1
  end
  local lines = { " Code Review", " " .. #files .. " files" }
  for i, file in ipairs(files) do
    local cursor = i == current_index and ">" or " "
    local reviewed = tonumber(file.reviewed) == 1 and "x" or " "
    local count = comment_counts[file.path] and (" [" .. comment_counts[file.path] .. "]") or ""
    table.insert(lines, string.format("%s %s %s %s%s", cursor, status_icon[file.status] or "M", reviewed, file.path, count))
  end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false
  vim.keymap.set("n", "<CR>", function()
    local idx = vim.api.nvim_win_get_cursor(0)[1] - 2
    if idx >= 1 and files[idx] then on_open(idx) end
  end, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "q", on_close, { buffer = M.buf, nowait = true })
end

function M.render(session, files, current_index, on_open, on_close)
  M.files = files
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.buf].buftype = "nofile"
    vim.bo[M.buf].bufhidden = "wipe"
    vim.bo[M.buf].filetype = "codereview-sidebar"
    vim.bo[M.buf].swapfile = false
  end
  if not M.win or not vim.api.nvim_win_is_valid(M.win) then
    M.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.win, M.buf)
  end
  vim.api.nvim_win_set_width(M.win, 28)
  configure_window(M.win)

  local comment_counts = {}
  for _, c in ipairs(queries.get_comments(session.id)) do
    comment_counts[c.file_path] = (comment_counts[c.file_path] or 0) + 1
  end

  local nodes, NuiTree = build_tree_nodes(files, current_index, comment_counts)
  if not nodes then
    fallback_render(session, files, current_index, on_open, on_close)
    return
  end

  local NuiLine = require("nui.line")
  M.tree = NuiTree({
    bufnr = M.buf,
    ns_id = "codereview-sidebar",
    nodes = nodes,
    prepare_node = function(node)
      local line = NuiLine()
      local depth = node:get_depth()
      line:append(string.rep("  ", math.max(depth - 1, 0)))

      if node.kind == "dir" then
        line:append(node:is_expanded() and " " or " ", "Directory")
        line:append(node.name, "Directory")
        return line
      end

      local file = node.file
      line:append(node.current and "> " or "  ", node.current and "CodeReviewSidebarTitle" or nil)
      line:append(status_icon[file.status] or "M", status_hl[file.status] or "CodeReviewFileModified")
      line:append(" ")
      line:append(tonumber(file.reviewed) == 1 and "x" or " ", tonumber(file.reviewed) == 1 and "CodeReviewReviewed" or nil)
      line:append(" ")
      local icon, icon_hl = get_icon(file.path)
      line:append(icon .. " ", icon_hl)
      line:append(node.name)
      if node.count > 0 then
        line:append(" [" .. node.count .. "]", "CodeReviewSign")
      end
      return line
    end,
  })
  M.tree:render()

  vim.keymap.set("n", "<CR>", function()
    local node = M.tree and M.tree:get_node()
    if node and node.kind == "file" then
      on_open(node.index)
    elseif node and node.kind == "dir" then
      if node:is_expanded() then node:collapse() else node:expand() end
      M.tree:render()
    end
  end, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "q", on_close, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "za", function()
    local node = M.tree and M.tree:get_node()
    if node and node.kind == "dir" then
      if node:is_expanded() then node:collapse() else node:expand() end
      M.tree:render()
    end
  end, { buffer = M.buf, nowait = true })
end

return M
