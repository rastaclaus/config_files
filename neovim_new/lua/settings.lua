-- Set highlight on search
vim.o.hlsearch = false

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = 'a'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Decrease update time
vim.o.updatetime = 250
vim.wo.signcolumn = 'yes'

-- Set colorscheme
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.codeschool_contrast_dark = "hard"
vim.g.gruvbox_material_background = 'hard'

vim.cmd [[colorscheme gruvbox-material]]

vim.o.completeopt = 'menuone,noselect' -- Set completeopt to have a better completion experience

vim.opt.cursorline = true -- higlight current line
vim.opt.scrolloff = 5 -- minimal number of screen lines to keep above and below the cursor
vim.opt.linebreak = true -- do not break the words

vim.opt.autoindent = true
vim.opt.expandtab = true -- Change tabs to spaces
vim.opt.shiftwidth = 4 -- Number of spaces to use for each step of (auto)indent.
vim.opt.tabstop = 4 -- Number of spaces that a <Tab> in the file counts for.
vim.opt.list = true
vim.opt.listchars = {tab="->", trail="-"}

vim.opt.wildmode = 'longest:full,full'

vim.fn.sign_define('DiagnosticSignError', { text = ' ', texthl = 'DiagnosticSignError' })
vim.fn.sign_define('DiagnosticSignWarn', { text = ' ', texthl = 'DiagnosticSignWarn' })
vim.fn.sign_define('DiagnosticSignInfo', { text = ' ', texthl = 'DiagnosticSignInfo' })
vim.fn.sign_define('DiagnosticSignHint', { text = ' ', texthl = 'DiagnosticSignHint' })

vim.g.python3_host_prog = os.getenv("HOME") ..  '/.pyenv/versions/neovim3/bin/python'
