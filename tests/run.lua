local M = {}

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assert_eq failed") .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "assert_true failed", 2)
  end
end

local function test_diff_parser()
  local parser = require("codereview.diff.parser")
  local files = parser.parse(table.concat({
    "diff --git a/a.lua b/a.lua",
    "--- a/a.lua",
    "+++ b/a.lua",
    "@@ -1,2 +1,2 @@",
    " local a = 1",
    "-local b = 2",
    "+local b = 3",
    "",
  }, "\n"))

  assert_eq(#files, 1, "one file parsed")
  assert_eq(files[1].path, "a.lua")
  assert_eq(files[1].status, "modified")
  assert_eq(#files[1].hunks, 1)
  assert_eq(files[1].hunks[1].lines[2].type, "remove")
  assert_eq(files[1].hunks[1].lines[3].new_lnum, 2)
end

local function test_clipboard_format()
  require("codereview").setup({})
  local queries = require("codereview.db.queries")
  local clipboard = require("codereview.clipboard")

  local session = queries.create_session({
    name = "test review",
    source_type = "diff_spec",
    repo_dir = "/tmp",
    base_ref = "base",
    target_ref = "target",
  })
  queries.create_comment({
    session_id = session.id,
    file_path = "src/example.lua",
    start_line = 2,
    end_line = 4,
    highlighted_text = "local x = 1",
    comment_text = "please check this",
  })

  local text = clipboard.dump(session, { include_snippets = true })
  assert_true(text:find("### Lines 2%-4") ~= nil, "uses readable line range heading")
  assert_true(text:find("```lua") ~= nil, "uses filetype fence")
  assert_true(text:find("please check this") ~= nil, "includes comment")
end

local function test_comment_extmarks()
  require("codereview").setup({})
  local diffview = require("codereview.ui.diffview")
  local extmarks = require("codereview.comments.extmarks")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
  diffview.current = {
    file = { status = "added" },
    maps = {
      new_display_to_real = {},
      new_real_to_display = {},
    },
  }

  assert_eq(diffview.display_to_real(2), 2)
  assert_eq(diffview.real_to_display(2), 2)
  assert_eq(extmarks.create(buf, { id = 1, start_line = 0, end_line = 0, comment_text = "bad" }), nil)

  local ids = extmarks.create(buf, {
    id = 2,
    start_line = 2,
    end_line = 2,
    comment_text = ("long comment "):rep(30),
  })
  assert_true(ids ~= nil, "valid comment renders")
  assert_eq(ids.start_display, 2)
  extmarks.toggle_expand(buf, 2)
  assert_true(extmarks.by_comment[2].expanded, "comment expands")
  assert_true(extmarks.by_comment[2].virt ~= nil, "expanded comment has virtual lines")
  extmarks.toggle_expand(buf, 2)
  assert_true(not extmarks.by_comment[2].expanded, "comment collapses")
  assert_eq(extmarks.by_comment[2].virt, nil, "collapsed comment removes virtual lines")
end

local function test_soft_delete()
  require("codereview").setup({})
  local queries = require("codereview.db.queries")
  local undo = require("codereview.undo")

  local session = queries.create_session({
    name = "delete test",
    source_type = "diff_spec",
    repo_dir = "/tmp",
    base_ref = "base",
    target_ref = "target",
  })
  local comment = queries.create_comment({
    session_id = session.id,
    file_path = "a.txt",
    start_line = 1,
    end_line = 1,
    highlighted_text = "a",
    comment_text = "remove me",
  })

  queries.soft_delete_comment(comment.id)
  undo.push(session.id, { type = "delete", comment_id = comment.id, before = comment })
  assert_eq(#queries.get_comments(session.id, "a.txt"), 0, "soft-deleted comments are hidden")
  assert_true(undo.undo(session.id), "undo delete")
  assert_eq(#queries.get_comments(session.id, "a.txt"), 1, "undo restores comment")
end

function M.run()
  local tests = {
    test_diff_parser,
    test_clipboard_format,
    test_comment_extmarks,
    test_soft_delete,
  }
  for _, test in ipairs(tests) do
    test()
  end
  print("codereview.nvim tests passed (" .. #tests .. ")")
end

return M
