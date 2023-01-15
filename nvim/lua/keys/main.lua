require('keys/alias')

vim.opt.langmap = 'ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ,фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz'

im('<C-k>', '<escape>')
nm('<leader><esc>', '<cmd>nohlsearch<CR>')

nm('[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>')
nm(']d', '<cmd>lua vim.diagnostic.goto_next()<CR>')
nm('<leader>e', '<cmd>lua vim.diagnostic.open_float()<CR>')
nm('<leader>q', '<cmd>lua vim.diagnostic.setloclist()<CR>')
