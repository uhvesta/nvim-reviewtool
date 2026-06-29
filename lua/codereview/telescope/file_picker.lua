local session = require("codereview.session")
local queries = require("codereview.db.queries")

local M = {}

function M.open()
  local state = session.current()
  if not state then return end
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.ui.select(state.files, {
      prompt = "CodeReview files",
      format_item = function(f) return f.status:sub(1, 1):upper() .. " " .. f.path end,
    }, function(file)
      if not file then return end
      for i, f in ipairs(state.files) do
        if f.id == file.id then session.open_file(i) return end
      end
    end)
    return
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local counts = {}
  for _, c in ipairs(queries.get_comments(state.session.id)) do
    counts[c.file_path] = (counts[c.file_path] or 0) + 1
  end
  pickers.new({}, {
    prompt_title = "CodeReview Files",
    finder = finders.new_table({
      results = state.files,
      entry_maker = function(file)
        local display = string.format("%s %s%s", file.status:sub(1, 1):upper(), file.path, counts[file.path] and (" [" .. counts[file.path] .. "]") or "")
        return { value = file, display = display, ordinal = display }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        for i, f in ipairs(state.files) do
          if f.id == entry.value.id then session.open_file(i) return end
        end
      end)
      return true
    end,
  }):find()
end

return M
