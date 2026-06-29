local diff_spec = require("codereview.source.diff_spec")

local M = {}

local function system(args)
  local out = vim.fn.systemlist(args)
  return vim.v.shell_error, out
end

local function refs(repo)
  local items = { "(working tree)", "HEAD" }
  local code, out = system({
    "git", "-C", repo, "for-each-ref", "--sort=-committerdate",
    "--format=%(refname:short)", "refs/heads/", "refs/tags/", "refs/remotes/",
  })
  if code == 0 then
    for _, line in ipairs(out) do
      if line ~= "" then
        table.insert(items, line)
      end
    end
  end
  return items
end

function M.resolve(callback)
  local repo = vim.trim(table.concat(vim.fn.systemlist({ "git", "-C", vim.fn.getcwd(), "rev-parse", "--show-toplevel" }), "\n"))
  local choices = refs(repo)
  vim.ui.select(choices, { prompt = "CodeReview base ref" }, function(base)
    if not base then return end
    vim.ui.select(choices, { prompt = "CodeReview target ref" }, function(target)
      if not target then return end
      local spec
      if target == "(working tree)" then
        spec = base == "(working tree)" and "HEAD" or base
      elseif base == "(working tree)" then
        spec = target
      else
        spec = base .. ".." .. target
      end
      local source = diff_spec.resolve(spec)
      source.source_type = "ref_picker"
      callback(source)
    end)
  end)
end

return M
