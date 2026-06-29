local M = {}

local defaults = {
  enable_lsp = true,
  include_snippets = true,
  checkout_dir = vim.fn.expand("~/nvim-gh-review"),
  keymaps = {
    new = "<leader>crN",
    resume = "<leader>crS",
    comment = "<leader>crc",
    toggle_comment = "<leader>crt",
    anchor_comment = "<leader>cra",
    comments = "<leader>crC",
    dump = "<leader>crd",
    next = "<leader>crn",
    prev = "<leader>crp",
    search = "<leader>crs",
    reviewed = "<leader>crr",
    summary = "<leader>crm",
    close = "<leader>crq",
    undo = "<leader>cru",
    redo = "<leader>crR",
  },
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  if type(M.options.enable_lsp) ~= "boolean" then
    error("codereview.enable_lsp must be a boolean")
  end
  if type(M.options.include_snippets) ~= "boolean" then
    error("codereview.include_snippets must be a boolean")
  end
  if type(M.options.checkout_dir) ~= "string" then
    error("codereview.checkout_dir must be a string")
  end
  return M.options
end

function M.get()
  return M.options
end

return M
