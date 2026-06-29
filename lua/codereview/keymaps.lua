local config = require("codereview.config")

local M = {}

function M.setup(api)
  local maps = config.get().keymaps
  vim.keymap.set("v", maps.comment, api.add_comment, { desc = "CodeReview comment" })
  vim.keymap.set("n", maps.dump, function() api.dump({}) end, { desc = "CodeReview dump" })
  vim.keymap.set("n", maps.next, api.next_file, { desc = "CodeReview next file" })
  vim.keymap.set("n", maps.prev, api.prev_file, { desc = "CodeReview previous file" })
  vim.keymap.set("n", maps.search, api.files, { desc = "CodeReview files" })
  vim.keymap.set("n", maps.reviewed, api.mark_reviewed, { desc = "CodeReview toggle reviewed" })
  vim.keymap.set("n", maps.undo, api.undo, { desc = "CodeReview undo" })
  vim.keymap.set("n", maps.redo, api.redo, { desc = "CodeReview redo" })
end

return M
