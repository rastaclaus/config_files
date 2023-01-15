local opt = vim.opt


opt.splitright = true
opt.splitbelow = true
opt.clipboard = "unnamedplus"
opt.fixeol = false
opt.completeopt = 'menuone,noselect'
opt.termguicolors = true
opt.swapfile = false
opt.undodir = vim.fn.stdpath('config') .. '/undodir'
opt.undofile = true
opt.hidden = true
opt.showmode = false

vim.cmd [[autocmd BufEnter * set fo-=c fo-=r fo-=o]]
vim.g.python3_host_prog = os.getenv("HOME") ..  '/.pyenv/versions/neovim3/bin/python'
vim.g.loaded_perl_provider = 0
