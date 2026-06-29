local queries = require("codereview.db.queries")

local M = {}

local function lang(path)
  return vim.filetype.match({ filename = path }) or ""
end

local function snippet(comment)
  if not comment.highlighted_text or comment.highlighted_text == "" then
    return nil
  end
  return comment.highlighted_text
end

function M.dump(session, opts)
  opts = opts or {}
  local include_snippets = opts.include_snippets ~= false
  local comments = queries.get_comments(session.id)
  local lines = {
    "# Code Review: " .. session.name,
    "",
    "- **Source**: " .. session.source_type,
    "- **Base**: `" .. session.base_ref .. "`",
    "- **Target**: `" .. session.target_ref .. "`",
    "- **Date**: " .. os.date("%Y-%m-%d %H:%M"),
    "",
    "---",
    "",
  }
  local current_file
  for _, comment in ipairs(comments) do
    if comment.file_path ~= current_file then
      current_file = comment.file_path
      table.insert(lines, "## `" .. current_file .. "`")
      table.insert(lines, "")
    end
    local range = comment.start_line == comment.end_line
        and ("L" .. comment.start_line)
        or ("L" .. comment.start_line .. "-L" .. comment.end_line)
    table.insert(lines, "### " .. range)
    table.insert(lines, "")
    local code = snippet(comment)
    if include_snippets and code then
      table.insert(lines, "```" .. lang(comment.file_path))
      for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
      end
      table.insert(lines, "```")
      table.insert(lines, "")
    end
    table.insert(lines, comment.comment_text)
    table.insert(lines, "")
  end
  return table.concat(lines, "\n")
end

function M.to_clipboard(text)
  vim.fn.setreg("+", text)
end

return M
