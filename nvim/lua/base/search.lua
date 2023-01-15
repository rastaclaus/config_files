local opt = vim.opt
local wo = vim.wo
local g = vim.g

opt.ignorecase = true
opt.smartcase = true
opt.showmatch = true
opt.incsearch = true
wo.number = true
wo.wrap = false
opt.wildmode = 'longest:full,full'
