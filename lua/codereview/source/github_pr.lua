local config = require("codereview.config")
local diff_spec = require("codereview.source.diff_spec")

local M = {}

local function system(args)
  local out = vim.fn.systemlist(args)
  return vim.v.shell_error, table.concat(out, "\n")
end

local function parse_url(url)
  return url:match("github%.com[:/](.-)/(.-)/pull/(%d+)")
end

function M.can_resolve(spec)
  return type(spec) == "string" and parse_url(spec) ~= nil
end

function M.resolve(url)
  local owner, repo_name, number = parse_url(url)
  if not owner then
    error("Invalid GitHub PR URL: " .. tostring(url))
  end
  local checkout = config.get().checkout_dir .. "/" .. owner .. "/" .. repo_name
  if vim.fn.isdirectory(checkout .. "/.git") == 0 then
    vim.fn.mkdir(vim.fn.fnamemodify(checkout, ":h"), "p")
    local code, out = system({ "gh", "repo", "clone", owner .. "/" .. repo_name, checkout, "--", "--depth=1" })
    if code ~= 0 then error(out) end
  end
  local code, out = system({ "git", "-C", checkout, "fetch", "origin", "pull/" .. number .. "/head:refs/remotes/origin/pr/" .. number })
  if code ~= 0 then error(out) end

  code, out = system({ "gh", "pr", "view", number, "--repo", owner .. "/" .. repo_name, "--json", "baseRefName,headRefName" })
  if code ~= 0 then error(out) end
  local meta = vim.json.decode(out)
  system({ "git", "-C", checkout, "fetch", "origin", meta.baseRefName })

  local cwd = vim.fn.getcwd()
  vim.cmd.lcd(vim.fn.fnameescape(checkout))
  local source = diff_spec.resolve("origin/" .. meta.baseRefName .. "..origin/pr/" .. number)
  vim.cmd.lcd(vim.fn.fnameescape(cwd))
  source.source_type = "github_pr"
  source.source_spec = url
  return source
end

return M
