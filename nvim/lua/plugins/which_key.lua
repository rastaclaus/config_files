require("which-key").setup({})

require("which-key").add({
	{ "<leader>v", group = "Review" },
})

vim.keymap.set("n", "<leader>hk", function()
    require("which-key").show()
end, {desc = "Show keymaps"})

vim.keymap.set("n", "<leader>?", function()
    require("which-key").show({global=false})
end, {desc = "Show local buffer keymaps"})
