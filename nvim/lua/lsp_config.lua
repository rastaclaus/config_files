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

-- Builtin completion from LSP (Neovim >= 0.12): 'omnifunc' feeds manual
-- completion (<C-Space>, <C-x><C-o>), and completion.enable() adds snippet/import
-- side effects on <C-y>. No autotrigger: the menu only opens on request.
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(event)
		local buf = event.buf
		vim.bo[buf].omnifunc = "v:lua.vim.lsp.omnifunc"
		vim.lsp.completion.enable(true, event.data.client_id, buf, { autotrigger = false })
	end,
})

-- Builtin :lsp subcommands (Neovim >= 0.12) instead of the removed :LspInfo family
vim.keymap.set("n", "<leader>lsp", ":checkhealth vim.lsp<CR>", { desc = "LSP health" })
vim.keymap.set("n", "<leader>lsd", ":lsp stop<CR>", { desc = "LSP stop" })
vim.keymap.set("n", "<leader>lse", ":lsp enable<CR>", { desc = "LSP enable" })
vim.keymap.set("n", "<leader>lsr", ":lsp restart<CR>", { desc = "LSP restart" })
