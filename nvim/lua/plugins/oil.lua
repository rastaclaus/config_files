local detail
require("oil").setup({
	keymaps = {
		["gd"] = {
			desc = "Toggle file detail view",
			callback = function()
				detail = not detail
				if detail then
					require("oil").set_columns({ "icon", "permissions", "size", "mtime" })
				else
					require("oil").set_columns({ "icon" })
				end
			end,
		},
	},
})

vim.keymap.set("n", "<leader>e", ":Oil<CR>", { desc = "Open file explorer" })
