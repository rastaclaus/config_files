vim.pack.add({
	-- Dependencies
	{ src = "https://github.com/nvim-tree/nvim-web-devicons" }, -- dependency

	-- https://github.com/ibhagwan/fzf-lua
	{ src = "https://github.com/ibhagwan/fzf-lua" },

	-- Colorscheme
	{ src = "https://github.com/ellisonleao/gruvbox.nvim"}, -- colorscheme

	-- Oil
	{ src = "https://github.com/stevearc/oil.nvim" }, -- file manager

	-- Helpers
	{ src = "https://github.com/stevearc/conform.nvim" }, -- formatting
	{ src = "https://github.com/folke/which-key.nvim" }, -- key suggestions
	{ src = "https://github.com/neovim/nvim-lspconfig" }, -- lsp autoconfig
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" }, -- parsers + queries

	-- Editing helpers
	{ src = "https://github.com/windwp/nvim-autopairs" }, -- autopairs
	{ src = "https://github.com/kylechui/nvim-surround"}, -- surround

	-- Markdown rendering
	{ src = "https://github.com/MeanderingProgrammer/render-markdown.nvim"}
})

require("plugins.treesitter")
require("plugins.oil")
require("plugins.fzflua")
require("plugins.which_key")
require("plugins.conform")
require("plugins.autopairs")
require("plugins.surround")
require("plugins.markdown")


require("plugins.colorschemes")
