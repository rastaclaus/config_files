require("render-markdown").setup({
	latex = { enabled = false },
	file_types = { "markdown" },
	-- review.nvim делает буфер ввода комментария markdown + nofile.
	-- Без этого render-markdown рисует virtual lines внутри floating-окна.
	ignore = function(buf)
		return vim.bo[buf].buftype == "nofile" and vim.bo[buf].filetype == "markdown"
	end,
})