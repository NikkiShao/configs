-- install lazy.nvim if missing
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({"git","clone","--filter=blob:none","https://github.com/folke/lazy.nvim.git","--branch=stable", lazypath})
end
vim.opt.rtp:prepend(lazypath)

-- basic editor settings
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cmdheight = 0
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- Enable treesitter highlighting for all filetypes with a parser
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
  end,
})

-- keymaps
vim.keymap.set('n', '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
vim.keymap.set('v', '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
vim.keymap.set('n', '<leader>p', '"+p', { desc = 'Paste from system clipboard' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Half page down, centered' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Half page up, centered' })
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlight' })
vim.keymap.set('n', '<leader>sv', '<cmd>vsplit<cr>', { desc = 'Vertical split' })
vim.keymap.set('n', '<leader>sh', '<cmd>split<cr>', { desc = 'Horizontal split' })
vim.keymap.set('n', '<leader>sx', '<cmd>close<cr>', { desc = 'Close split' })
vim.keymap.set({'n', 'v'}, 'J', '10j', { noremap = true, desc = 'Jump 10 lines down' })
vim.keymap.set({'n', 'v'}, 'K', '10k', { noremap = true, desc = 'Jump 10 lines up' })
-- Move lines with Cmd+J/K (Ghostty sends Alt+J/K)
vim.keymap.set('v', '<M-J>', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('v', '<M-K>', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })
vim.keymap.set('n', '<M-J>', ":m .+1<CR>==", { desc = 'Move line down' })
vim.keymap.set('n', '<M-K>', ":m .-2<CR>==", { desc = 'Move line up' })
-- Duplicate lines with Cmd+Shift+J/K (Ghostty sends Alt+j/k)
vim.keymap.set('n', '<M-j>', ":t .-1<CR>", { desc = 'Duplicate line up' })
vim.keymap.set('n', '<M-k>', ":t .<CR>", { desc = 'Duplicate line down' })
vim.keymap.set('v', '<M-j>', ":t '<-1<CR>gv", { desc = 'Duplicate selection up' })
vim.keymap.set('v', '<M-k>', ":t '><CR>gv", { desc = 'Duplicate selection down' })

vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to left split' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to below split' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to above split' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to right split' })

-- Auto-reload files changed outside of Neovim
vim.o.autoread = true
vim.o.updatetime = 250
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  command = "if mode() != 'c' | checktime | endif",
})

-- Dim background when pane loses focus (works with tmux focus-events)
vim.api.nvim_create_autocmd("FocusLost", {
  callback = function()
    vim.api.nvim_set_hl(0, "Normal", { bg = "#181825" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "#181825" })
  end,
})
vim.api.nvim_create_autocmd("FocusGained", {
  callback = function()
    vim.api.nvim_set_hl(0, "Normal", { bg = "#1e1e2e" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "#1e1e2e" })
  end,
})

require("lazy").setup("plugins")
