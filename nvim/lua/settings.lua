local o = vim.o
local wo = vim.wo
local bo = vim.bo

o.swapfile = false
o.backup = false
o.undodir = vim.fn.stdpath('config') .. '/undodir'
o.undofile = true
o.termguicolors = true
o.syntax = 'on'
o.hidden = true
o.completeopt='menuone,noinsert,noselect'
bo.autoindent = true
bo.smartindent = true
o.hlsearch = true
o.laststatus = 2
o.smartcase = true
o.incsearch = true
o.ignorecase = true
o.showmode = false
o.scrolloff = 12

vim.opt.list = true
vim.opt.listchars = {tab="->", trail="-"}


o.tabstop = 4
o.softtabstop = 4
o.shitwidth = 4
o.expandtab = true
wo.wrap = false
wo.number = true
--wo.signcolumn = 'yes'
vim.opt.wildmode = 'longest:full,full'

vim.fn.sign_define('DiagnosticSignError', { text = ' ', texthl = 'DiagnosticSignError' })
vim.fn.sign_define('DiagnosticSignWarn', { text = ' ', texthl = 'DiagnosticSignWarn' })
vim.fn.sign_define('DiagnosticSignInfo', { text = ' ', texthl = 'DiagnosticSignInfo' })
vim.fn.sign_define('DiagnosticSignHint', { text = ' ', texthl = 'DiagnosticSignHint' })

vim.g.python3_host_prog = os.getenv("HOME") ..  '/.pyenv/versions/neovim3/bin/python'
