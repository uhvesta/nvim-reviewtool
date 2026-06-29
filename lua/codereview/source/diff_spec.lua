local parser = require("codereview.diff.parser")

local M = {}

local function system(args)
  local out = vim.fn.systemlist(args)
  return vim.v.shell_error, table.concat(out, "\n"), out
end

local function repo_root()
  local code, out = system({ "git", "-C", vim.fn.getcwd(), "rev-parse", "--show-toplevel" })
  if code ~= 0 then
    error("Not inside a git repository")
  end
  return vim.trim(out)
end

local function rev_parse(repo, ref)
  if not ref or ref == "" or ref == "WORKING_TREE" then
    return "WORKING_TREE"
  end
  local code, out = system({ "git", "-C", repo, "rev-parse", ref })
  if code ~= 0 then
    return ref
  end
  return vim.trim(out)
end

local function split_refs(spec)
  if spec:find("%.%.%.") then
    local a, b = spec:match("^(.-)%.%.%.(.+)$")
    return a, b
  end
  if spec:find("%.%.") then
    local a, b = spec:match("^(.-)%.%.(.+)$")
    return a, b
  end
  return spec, "WORKING_TREE"
end

local function untracked_files(repo)
  local code, _, lines = system({ "git", "-C", repo, "ls-files", "--others", "--exclude-standard" })
  if code ~= 0 then
    return {}
  end
  local files = {}
  for _, path in ipairs(lines) do
    if path ~= "" then
      table.insert(files, {
        path = path,
        status = "added",
        hunks = {},
        binary = false,
        untracked = true,
      })
    end
  end
  return files
end

function M.resolve(spec)
  local repo = repo_root()
  spec = spec and vim.trim(spec) or "HEAD"
  local args = { "git", "-C", repo, "diff", "--no-ext-diff", "--find-renames", "--binary" }
  for part in spec:gmatch("%S+") do
    table.insert(args, part)
  end
  local code, diff = system(args)
  if code ~= 0 then
    error(diff)
  end
  local files = parser.parse(diff)
  for _, f in ipairs(untracked_files(repo)) do
    table.insert(files, f)
  end
  local base, target = split_refs(spec)
  return {
    base_ref = rev_parse(repo, base),
    target_ref = rev_parse(repo, target),
    file_list = files,
    repo_dir = repo,
    source_type = "diff_spec",
    source_spec = spec,
  }
end

return M
