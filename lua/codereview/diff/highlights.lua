local M = {}

M.ns = vim.api.nvim_create_namespace("codereview-diff")

function M.setup()
  vim.api.nvim_set_hl(0, "CodeReviewAdded", { bg = "#2d4a2d", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewRemoved", { bg = "#4a2d2d", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewFiller", { bg = "#333333", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewSign", { fg = "#61afef", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewAnnotatedRegion", { bg = "#2a3a4a", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewCommentHeader", { fg = "#8a8a8a", italic = true, default = true })
  vim.api.nvim_set_hl(0, "CodeReviewCommentBody", { fg = "#d0d0d0", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewSidebarTitle", { fg = "#61afef", bold = true, default = true })
  vim.api.nvim_set_hl(0, "CodeReviewFileModified", { fg = "#e5c07b", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewFileAdded", { fg = "#98c379", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewFileDeleted", { fg = "#e06c75", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewFileRenamed", { fg = "#c678dd", default = true })
  vim.api.nvim_set_hl(0, "CodeReviewReviewed", { fg = "#98c379", default = true })
end

function M.clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
end

function M.line(buf, lnum, group)
  vim.api.nvim_buf_set_extmark(buf, M.ns, lnum - 1, 0, {
    line_hl_group = group,
    hl_eol = true,
  })
end

return M
