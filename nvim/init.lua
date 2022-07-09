-- Install packer
local install_path = vim.fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"

if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.fn.execute("!git clone https://github.com/wbthomason/packer.nvim " .. install_path)
    vim.cmd [[packadd packer.nvim]]
end

require("plugins")
require("plugins-settings")
require("lsp-settings")
require("settings")
require("maps")
require("autocmd")
require("colorscheme")
