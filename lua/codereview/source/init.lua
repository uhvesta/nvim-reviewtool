local diff_spec = require("codereview.source.diff_spec")
local ref_picker = require("codereview.source.ref_picker")
local github_pr = require("codereview.source.github_pr")

local M = {}

function M.resolve(spec, callback)
  if spec == nil or vim.trim(spec) == "" then
    return ref_picker.resolve(callback)
  end
  local ok, source_or_err
  if github_pr.can_resolve(spec) then
    ok, source_or_err = pcall(github_pr.resolve, spec)
  else
    ok, source_or_err = pcall(diff_spec.resolve, spec)
  end
  if not ok then
    vim.notify(source_or_err, vim.log.levels.ERROR)
    return
  end
  callback(source_or_err)
end

return M
