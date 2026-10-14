require("conform").setup({
	formatters_by_ft = {
		javascript = { "prettier" },
		typescript = { "prettier" },
		javascriptreact = { "prettier" },
		typescriptreact = { "prettier" },
		svelte = { "prettier" },
		css = { "prettier" },
		html = { "prettier" },
		json = { "jq" },
		yaml = { "prettier" },
		markdown = { "prettier" },
		graphql = { "prettier" },
		lua = { "stylua" },
		python = { "ruff_format" },
		go = { "gofmt" },
		rust = { "rustfmt" },
		toml = { "pyproject-fmt" },
		sh = { "shfmt" },
		bash = { "shfmt" },
	},
	format_on_save = nil,
	formatters = {
		ruff_format = {
			prepend_args = { "--config", "~/.ruff.toml" },
		},
	},
})


-- Format keymap
vim.keymap.set("n", "<leader>lf", require("conform").format, {desc = "Format Buffer" })
vim.keymap.set("v", "<leader>f", require("conform").format, {desc = "Format Selection"})
