local map = vim.api.nvim_set_keymap

vim.g.mapleader = ' '

function nm(key, command)
    map('n', key, command, { noremap = true })
end

function im(key, command)
    map('i', key, command, { noremap = true })
end

function vm(key, command)
    map('v', key, command, { noremap = true })
end

function vm(key, command)
    map('t', key, command, { noremap = true })
end
