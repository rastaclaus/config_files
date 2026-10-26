-- Inline-ревью изменений: значки в signcolumn, хунки, stage/reset.
-- Маппинги buffer-local: создаются только там, где есть git.
require("gitsigns").setup({
	signs = {
		add = { text = "┃" },
		change = { text = "┃" },
		delete = { text = "_" },
		topdelete = { text = "‾" },
		changedelete = { text = "~" },
		untracked = { text = "┆" },
	},
	signs_staged = {
		add = { text = "┃" },
		change = { text = "┃" },
		delete = { text = "_" },
		topdelete = { text = "‾" },
		changedelete = { text = "~" },
		untracked = { text = "┆" },
	},
	signs_staged_enable = true, -- отдельные значки для застейдженного
	attach_to_untracked = true, -- значки и в новых файлах
	current_line_blame = false, -- включается по <leader>hB
	word_diff = false, -- включается по <leader>hw
	on_attach = function(bufnr)
		local gs = require("gitsigns")

		local function map(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
		end

		-- Навигация: в diff-режиме отдаём нативным ]c/[c
		map("n", "]c", function()
			if vim.wo.diff then
				return vim.cmd.normal({ "]c", bang = true })
			end
			gs.nav_hunk("next")
		end, "Next hunk")
		map("n", "[c", function()
			if vim.wo.diff then
				return vim.cmd.normal({ "[c", bang = true })
			end
			gs.nav_hunk("prev")
		end, "Previous hunk")

		-- Стейджинг
		map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
		map("v", "<leader>hs", function()
			gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "Stage selection")
		map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
		map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
		map("v", "<leader>hr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "Reset selection")
		map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
		map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")

		-- Просмотр
		map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
		map("n", "<leader>hi", gs.preview_hunk_inline, "Preview hunk inline")
		map("n", "<leader>hd", gs.diffthis, "Diff vs index")
		map("n", "<leader>hD", function()
			gs.diffthis("~")
		end, "Diff vs previous commit")
		map("n", "<leader>hb", function()
			gs.blame_line({ full = true })
		end, "Blame line")
		map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle line blame")
		map("n", "<leader>hw", gs.toggle_word_diff, "Toggle word diff")
		map("n", "<leader>hq", gs.setqflist, "Hunks to quickfix")

		-- Text object: i h
		map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
	end,
})
