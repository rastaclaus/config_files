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

-- Builtin completion from LSP (Neovim >= 0.12): 'omnifunc' feeds completion,
-- and completion.enable() adds snippet/import side effects on <C-y>.
-- The menu itself is raised by 'autocomplete' (see options.lua): it is enabled
-- per buffer on LspAttach and disabled on LspDetach. 'autotrigger' is not used —
-- with 'autocomplete' + 'complete=o' it only duplicates requests.
-- In LSP buffers 'complete' is narrowed to 'o' so the menu carries LSP items
-- only; buffer words remain available via <C-x><C-n>.
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(event)
		local buf = event.buf
		vim.bo[buf].omnifunc = "v:lua.vim.lsp.omnifunc"
		vim.lsp.completion.enable(true, event.data.client_id, buf, { autotrigger = false })
		vim.bo[buf].complete = "o"
		vim.bo[buf].autocomplete = true
	end,
})

vim.api.nvim_create_autocmd("LspDetach", {
	callback = function(event)
		if #vim.lsp.get_clients({ bufnr = event.buf }) == 0 then
			vim.bo[event.buf].complete = nil      -- fall back to the global value
			vim.bo[event.buf].autocomplete = nil
		end
	end,
})

-- Builtin :lsp subcommands (Neovim >= 0.12) instead of the removed :LspInfo family
vim.keymap.set("n", "<leader>lsp", ":checkhealth vim.lsp<CR>", { desc = "LSP health" })
vim.keymap.set("n", "<leader>lsd", ":lsp stop<CR>", { desc = "LSP stop" })
vim.keymap.set("n", "<leader>lse", ":lsp enable<CR>", { desc = "LSP enable" })
vim.keymap.set("n", "<leader>lsr", ":lsp restart<CR>", { desc = "LSP restart" })
