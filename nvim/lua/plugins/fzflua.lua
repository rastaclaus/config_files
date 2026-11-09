require('fzf-lua').setup({})
-- vim.cmd("FzfLua register_ui_select")

-- Восстановить командную строку после отмены в fzf (см. маппинг <C-x><C-f> ниже).
local function restore_cmdline(line, pos)
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes(":" .. line, true, false, true), "n", false)
	vim.schedule(function()
		vim.fn.setcmdline(line, pos)
	end)
end

-- Подстановка имени файла из fzf в командную строку (:e, :vne, :sp, :tabnew, :source, ...).
-- Пока набираем Ex-команду, <C-x><C-f> открывает тот же picker, что <leader>ff,
-- и вставляет выбранный файл на место курсора. Отмена (Esc/<C-c>) восстанавливает
-- исходную командную строку с уже набранным текстом.
-- В режимах вне ":"-команд (<C-f> в cmdline-window, /-поиск) сохраняем дефолт <C-f>.
vim.keymap.set("c", "<C-x><C-f>", function()
	if vim.fn.getcmdtype() ~= ":" then return "<C-f>" end
	local line, pos = vim.fn.getcmdline(), vim.fn.getcmdpos()
	vim.schedule(function()
		require("fzf-lua").files({
			actions = {
				["enter"] = function(selected)
					local file = selected and selected[1]
					if not file then return end
					local newline = line:sub(1, pos - 1)
						.. vim.fn.fnameescape(file) .. line:sub(pos)
					vim.api.nvim_feedkeys(
						vim.api.nvim_replace_termcodes(":" .. newline, true, false, true), "n", false)
					-- Без <CR>: команда остаётся в cmdline, Enter жмёт пользователь.
				end,
				-- Esc/<C-c> в fzf: вернуть командную строку как была.
				["esc"] = function() restore_cmdline(line, pos) end,
				["ctrl-c"] = function() restore_cmdline(line, pos) end,
			},
		})
	end)
	-- Закрываем cmdline; fzf откроется из schedule уже в normal mode.
	return "<C-c>"
end, { expr = true, desc = "Вставить файл из fzf в командную строку" })

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

