local M = {}

function M.open(on_submit)
  local width = math.min(80, math.floor(vim.o.columns * 0.7))
  local height = math.min(12, math.floor(vim.o.lines * 0.4))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = "Review Comment",
    title_pos = "center",
  })

  local submitted = false
  local function submit()
    if submitted then return end
    submitted = true
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if text ~= "" then
      on_submit(text)
    end
  end
  local function cancel()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "<CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<C-s>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<C-s>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<C-CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("n", "ZZ", submit, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", cancel, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<C-c>", cancel, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<C-c>", cancel, { buffer = buf, nowait = true })
  vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = submit })
  vim.cmd.startinsert()
end

return M
