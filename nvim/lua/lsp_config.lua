-- Better LSP UI
vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "✗",
			[vim.diagnostic.severity.WARN] = "⚠",
			[vim.diagnostic.severity.INFO] = "ℹ",
			[vim.diagnostic.severity.HINT] = "💡",
		},
	},
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = {
		source = true,
	},
})

vim.lsp.enable({ "lua_ls", "ruff", "ty", "gopls", "rust_analyzer", "jsonls", "yamlls", "dockerls" })

vim.keymap.set("n", "<leader>lsp", ":LspInfo<CR>", { desc = "LspInfo" })
vim.keymap.set("n", "<leader>lsd", ":LspStop<CR>", { desc = "LspStop" })
vim.keymap.set("n", "<leader>lse", ":LspStart<CR>", { desc = "LspStart" })
vim.keymap.set("n", "<leader>lsr", ":LspRestart<CR>", { desc = "LspRestart" })
