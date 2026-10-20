-- Basic autocommands
local augroup = vim.api.nvim_create_augroup("UserConfig", {})

-- Highlight yanked/put text (brief flash, no lingering)
local hl_op = { higroup = "IncSearch", timeout = 120, priority = vim.hl.priorities.user }
vim.api.nvim_create_autocmd({ "TextYankPost", "TextPutPost" }, {
	group = augroup,
	callback = function()
		vim.hl.hl_op(hl_op)
	end,
})

-- Return to last edit position when opening files
vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup,
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- Set filetype-specific settings
vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = { "python" },
	callback = function()
		vim.opt_local.tabstop = 4
		vim.opt_local.shiftwidth = 4
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = { "lua" },
	callback = function()
		vim.opt_local.tabstop = 4
		vim.opt_local.shiftwidth = 4
		vim.opt_local.expandtab = false
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = { "javascript", "typescript", "json", "html", "css" },
	callback = function()
		vim.opt_local.tabstop = 2
		vim.opt_local.shiftwidth = 2
	end,
})

-- Auto-close terminal when process exits
-- vim.api.nvim_create_autocmd("TermClose", {
-- 	group = augroup,
-- 	callback = function()
-- 		if vim.v.event.status == 0 then
-- 			vim.api.nvim_buf_delete(0, {})
-- 		end
-- 	end,
-- })

-- Builtin cmdline autocompletion (Neovim >= 0.12): show suggestions while typing
vim.api.nvim_create_autocmd("CmdlineChanged", {
	group = augroup,
	pattern = { ":", "/", "?" },
	callback = function()
		vim.fn.wildtrigger()
	end,
})

-- Auto-resize splits when window is resized
vim.api.nvim_create_autocmd("VimResized", {
	group = augroup,
	callback = function()
		vim.cmd("tabdo wincmd =")
	end,
})

vim.filetype.add({
	pattern = {
		[".*docker%-compose.*%.ya?ml"] = "yaml.docker-compose",
		[".*gitlab%-ci.*%.ya?ml"] = "yaml.gitlab",
		[".*values%.ya?ml"] = "yaml.helm-values",
	},
	filename = {
		["go.work"] = "gowork",
	},
	extension = {
		gotmpl = "gotmpl",
	},
})

vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "markdown",
	callback = function()
		vim.opt_local.conceallevel = 2
	end,
})

-- Ревью перед коммитом: `git config commit.verbose true` кладёт в
-- COMMIT_EDITMSG diff застейдженного; :DiffGitCached (встроенный ftplugin
-- gitcommit) открывает тот же diff отдельным сплитом.
vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "gitcommit",
	callback = function()
		vim.opt_local.spell = true
		vim.keymap.set("n", "<leader>gp", ":DiffGitCached<CR>", {
			buffer = true,
			desc = "Preview staged diff",
		})
	end,
})


-- Create directories when saving files
vim.api.nvim_create_autocmd("BufWritePre", {
	group = augroup,
	callback = function()
		if vim.bo.filetype == "oil" or vim.api.nvim_buf_get_name(0) == "" then
			return
		end

		local dir = vim.fn.expand("<afile>:p:h")
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, "p")
		end
	end,
})
