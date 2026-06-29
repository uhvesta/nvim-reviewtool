if vim.g.loaded_codereview_nvim == 1 then
  return
end
vim.g.loaded_codereview_nvim = 1

local function api()
  return require("codereview")
end

local subcommands = {
  new = function(args) api().new(table.concat(args.fargs, " ")) end,
  resume = function(args) api().resume(args.fargs[1] and tonumber(args.fargs[1]) or nil) end,
  files = function() api().files() end,
  next = function() api().next_file() end,
  prev = function() api().prev_file() end,
  comment = function() api().add_comment() end,
  comments = function() api().comments() end,
  anchor = function() api().anchor_comment() end,
  delete = function() api().delete_comment() end,
  reviewed = function() api().mark_reviewed() end,
  dump = function(args)
    api().dump({ no_snippets = vim.tbl_contains(args.fargs, "--no-snippets") })
  end,
  summary = function() api().summary() end,
  close = function() api().close() end,
  undo = function() api().undo() end,
  redo = function() api().redo() end,
}

vim.api.nvim_create_user_command("CodeReview", function(args)
  local cmd = args.fargs[1]
  if not cmd or cmd == "" then
    vim.notify("Usage: CodeReview <new|resume|files|next|prev|comment|comments|anchor|delete|reviewed|dump|summary|close|undo|redo>", vim.log.levels.INFO)
    return
  end
  local handler = subcommands[cmd]
  if not handler then
    vim.notify("Unknown CodeReview command: " .. cmd, vim.log.levels.ERROR)
    return
  end
  local shifted = vim.deepcopy(args)
  shifted.fargs = vim.list_slice(args.fargs, 2)
  handler(shifted)
end, {
  nargs = "*",
  complete = function(arglead, cmdline)
    local words = vim.split(cmdline, "%s+")
    if #words <= 2 then
      return vim.tbl_filter(function(cmd) return vim.startswith(cmd, arglead) end, vim.tbl_keys(subcommands))
    end
    return {}
  end,
})
