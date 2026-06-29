vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"))
vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/nvim/lazy/telescope.nvim"))
vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/nvim/lazy/nvim-web-devicons"))

vim.g.mapleader = " "
vim.notify = function() end
