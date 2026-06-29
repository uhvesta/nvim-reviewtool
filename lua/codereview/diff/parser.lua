local M = {}

local function starts_with(s, prefix)
  return s:sub(1, #prefix) == prefix
end

local function new_file(path)
  return {
    path = path,
    old_path = nil,
    status = "modified",
    hunks = {},
    binary = false,
  }
end

local function parse_hunk_header(line)
  local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
  if not old_start then
    return nil
  end
  return {
    old_start = tonumber(old_start),
    old_count = tonumber(old_count ~= "" and old_count or "1"),
    new_start = tonumber(new_start),
    new_count = tonumber(new_count ~= "" and new_count or "1"),
    lines = {},
  }
end

function M.parse(diff_output)
  local files = {}
  local current = nil
  local hunk = nil
  local old_lnum = nil
  local new_lnum = nil

  for line in (diff_output .. "\n"):gmatch("([^\n]*)\n") do
    if starts_with(line, "diff --git ") then
      local old_path, new_path = line:match("^diff %-%-git a/(.-) b/(.+)$")
      current = new_file(new_path or old_path or "")
      table.insert(files, current)
      hunk = nil
    elseif current and starts_with(line, "Binary files ") then
      current.binary = true
    elseif current and starts_with(line, "new file mode") then
      current.status = "added"
    elseif current and starts_with(line, "deleted file mode") then
      current.status = "deleted"
    elseif current and starts_with(line, "rename from ") then
      current.status = "renamed"
      current.old_path = line:sub(#"rename from " + 1)
    elseif current and starts_with(line, "rename to ") then
      current.path = line:sub(#"rename to " + 1)
    elseif current and starts_with(line, "--- ") then
      local p = line:match("^%-%-%- a/(.+)$")
      if p and current.status == "deleted" then
        current.old_path = p
      end
    elseif current and starts_with(line, "+++ ") then
      local p = line:match("^%+%+%+ b/(.+)$")
      if p then
        current.path = p
      end
    elseif current and starts_with(line, "@@ ") then
      hunk = parse_hunk_header(line)
      if hunk then
        old_lnum = hunk.old_start
        new_lnum = hunk.new_start
        table.insert(current.hunks, hunk)
      end
    elseif current and hunk and line ~= "\\ No newline at end of file" then
      local marker = line:sub(1, 1)
      local text = line:sub(2)
      if marker == "+" then
        table.insert(hunk.lines, { type = "add", old_lnum = nil, new_lnum = new_lnum, text = text })
        new_lnum = new_lnum + 1
      elseif marker == "-" then
        table.insert(hunk.lines, { type = "remove", old_lnum = old_lnum, new_lnum = nil, text = text })
        old_lnum = old_lnum + 1
      elseif marker == " " then
        table.insert(hunk.lines, { type = "context", old_lnum = old_lnum, new_lnum = new_lnum, text = text })
        old_lnum = old_lnum + 1
        new_lnum = new_lnum + 1
      end
    end
  end

  return files
end

return M
