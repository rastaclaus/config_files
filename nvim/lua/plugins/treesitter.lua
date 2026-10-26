-- Parsers and queries (nvim-treesitter "main" branch, Neovim >= 0.12).
-- Parsers are installed into stdpath('data')/site and stay there; install() is a
-- no-op for languages that are already present.
local parsers = {
	"bash",
	"c",
	"css",
	"diff",
	"dockerfile",
	"go",
	"gotmpl",
	"html",
	"javascript",
	"json",
	"lua",
	"markdown",
	"markdown_inline",
	"python",
	"query",
	"regex",
	"rust",
	"toml",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"yaml",
}

local task = require("nvim-treesitter").install(parsers)

-- install.sh runs Neovim with NVIM_TS_INSTALL_SYNC=1 so parsers are built
-- during provisioning instead of in the background after the first start.
-- A failed parser must not abort the rest of the config.
if vim.env.NVIM_TS_INSTALL_SYNC == "1" then
	pcall(task.wait, task, 600000)
end

-- Treesitter highlighting is not enabled globally by Neovim: turn it on for the
-- filetypes we actually edit (runtime ftplugins already cover lua/markdown/...).
vim.api.nvim_create_autocmd("FileType", {
	pattern = {
		"bash",
		"c",
		"css",
		"dockerfile",
		"go",
		"gotmpl",
		"html",
		"javascript",
		"javascriptreact",
		"json",
		"python",
		"rust",
		"toml",
		"tsx",
		"typescript",
		"typescriptreact",
		"yaml",
	},
	callback = function()
		pcall(vim.treesitter.start)
	end,
})
