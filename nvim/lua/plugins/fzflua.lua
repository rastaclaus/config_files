require('fzf-lua').setup({})
-- vim.cmd("FzfLua register_ui_select")

vim.keymap.set("n", "<leader>ff", ":FzfLua files<CR>", { desc = "Find file" })
vim.keymap.set("n", "<leader>fg", ":FzfLua grep_project<CR>", { desc = "Grep project" })
vim.keymap.set("n", "<leader>fb", ":FzfLua buffers<CR>", { desc = "Find buffer" })
vim.keymap.set("n", "<leader>fqq", ":FzfLua diagnostics_document<CR>", { desc = "Find diagnostics document" })
vim.keymap.set("n", "<leader>fqw", ":FzfLua diagnostics_workspace<CR>", { desc = "Find diagnostics workspace" })

vim.keymap.set("n", "gra", ":FzfLua lsp_code_actions<CR>", { desc = "LSP code actions" })

vim.keymap.set("n", "gd", ":FzfLua lsp_definitions<CR>", { desc = "LSP definitions" })
vim.keymap.set("n", "gD", ":FzfLua lsp_declarations<CR>", { desc = "LSP declarations" })
vim.keymap.set("n", "grr", ":FzfLua lsp_references<CR>", { desc = "LSP references" })
vim.keymap.set("n", "gri", ":FzfLua lsp_implementations<CR>", { desc = "LSP implementations" })
vim.keymap.set("n", "grt", ":FzfLua lsp_typedefs<CR>", { desc = "LSP type definitions" })

-- Git: обзор изменений перед коммитом (inline-часть — в plugins/gitsigns.lua)
vim.keymap.set("n", "<leader>gg", ":FzfLua git_status<CR>", { desc = "Git status" })
vim.keymap.set("n", "<leader>gh", ":FzfLua git_hunks<CR>", { desc = "Git hunks" })
vim.keymap.set("n", "<leader>gl", ":FzfLua git_commits<CR>", { desc = "Git log (project)" })
vim.keymap.set("n", "<leader>gL", ":FzfLua git_bcommits<CR>", { desc = "Git log (buffer)" })
vim.keymap.set("n", "<leader>gb", ":FzfLua git_blame<CR>", { desc = "Git blame (buffer)" })

-- Всё, что изменилось с HEAD (индекс + рабочее дерево).
vim.keymap.set("n", "<leader>gd", function()
	require("fzf-lua").git_diff({ ref = "HEAD" })
end, { desc = "Git diff since HEAD" })

-- Только индекс: ровно то, что уйдёт в следующий коммит.
vim.keymap.set("n", "<leader>gD", function()
	require("fzf-lua").git_diff({
		cmd = "git --no-pager diff --cached --color=always --name-only",
		preview = "git diff --cached --color=always -- {file}",
	})
end, { desc = "Git staged diff" })

