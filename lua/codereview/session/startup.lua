local queries = require("codereview.db.queries")
local session = require("codereview.session")

local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      vim.defer_fn(function()
        local sessions = queries.list_sessions({ status = "active" })
        if #sessions == 0 then return end
        vim.ui.select({ "yes", "no" }, {
          prompt = "You have " .. #sessions .. " active review sessions. Resume?",
        }, function(choice)
          if choice == "yes" then session.resume() end
        end)
      end, 100)
    end,
  })
end

return M
