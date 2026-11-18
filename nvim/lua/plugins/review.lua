-- Ревью изменений с комментариями: unified diff в отдельном табе.
-- Просмотр диффов для gitsigns убран, поэтому это основной вход:
-- <leader>vo — рабочее дерево против HEAD, <leader>vb — ветка от merge-base.
-- Экспорт: markdown в clipboard и в state-каталог, дальше его читает harness.
local function on_export(content, comments)
	if #comments == 0 then
		vim.notify("review: no comments to export", vim.log.levels.WARN)
		return false
	end

	local dir = vim.fn.stdpath("state") .. "/review"
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	-- У review-комментариев и quick comments разные заголовки, не перетираем
	-- последний экспорт друг друга.
	local name = content:match("^# Quick Comments") and "quick-latest.md" or "latest.md"
	local path = dir .. "/" .. name
	if vim.fn.writefile(vim.split(content, "\n", { plain = true }), path) ~= 0 then
		vim.notify("review: write failed: " .. path, vim.log.levels.ERROR)
		return false
	end

	vim.notify(("%d comment(s) -> %s"):format(#comments, path), vim.log.levels.INFO)
	return true
end

-- review.nvim красит интерфейс фиксированной тёмной палитрой. В светлой теме
-- это даёт светлый текст на светлом фоне и тёмный текст на тёмных diff-фонах.
-- Подменяем палитру до require("review"), чтобы наш ColorScheme-autocmd
-- регистрировался раньше плагинного и при смене темы обновлял цвета первым.
local palette = require("review.ui.palette")
local dark_palette = vim.deepcopy(palette)
local light_palette = {
	positive = "#427b58",
	negative = "#9d0006",
	caution = "#af3a03",
	accent = "#076678",
	highlight = "#b57614",
	special = "#8f3f71",

	text = "#3c3836",
	muted = "#665c54",
	faded = "#7c6f64",

	border = "#a89984",
	border_accent = "#076678",

	diff_add = "#d5d39b",
	diff_add_emphasis = "#b8d8a8",
	diff_delete = "#fc9487",
	diff_delete_emphasis = "#f4a3a3",

	selected = "#d5c4a1",
	surface = "#ebdbb2",
	header = "#e8e5b5",
	tint = "#f2e5bc",
	padding = "#f2e5bc",
	cursor_line = "#ebdbb2",

	author1 = "#076678",
	author2 = "#8f3f71",
	author3 = "#b57614",
	author4 = "#427b58",
	author5 = "#d65d0e",
	author6 = "#9d0006",
}

local function apply_review_palette()
	local colors = vim.o.background == "light" and light_palette or dark_palette
	for key, value in pairs(colors) do
		palette[key] = value
	end
end

apply_review_palette()
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("ReviewPalette", { clear = true }),
	callback = apply_review_palette,
})

require("review").setup({
	diff = { base = "HEAD" },
	ui = { diff_view_mode = "unified", line_stats = true },
	quick_comments = { signs = { enabled = true } },
	export = { context_lines = 3, on_export = on_export },
	auto_refresh = { enabled = true, debounce_ms = 300 },
	persistence = { enabled = true },
})

-- Ревью ветки от точки ответвления. :Review commit <sha> ставит base=sha и
-- не задаёт base_end, поэтому в дифф входит и незакоммиченное рабочее дерево.
local function branch_review()
	local sha = require("git_util").branch_point()
	if not sha then
		vim.notify(
			"review: базовая ветка не найдена (origin/HEAD, main, master)",
			vim.log.levels.WARN
		)
		return
	end
	vim.cmd("Review commit " .. sha)
	require("review").open()
end

vim.keymap.set("n", "<leader>vo", "<cmd>Review<cr>", { desc = "Review: open (worktree vs HEAD)" })
vim.keymap.set("n", "<leader>vb", branch_review, { desc = "Review: branch since merge-base" })
vim.keymap.set("n", "<leader>vc", function()
	require("review.quick_comments").add()
end, { desc = "Review: comment line" })
vim.keymap.set("v", "<leader>vc", function()
	require("review.quick_comments").add_visual()
end, { desc = "Review: comment selection" })
vim.keymap.set("n", "<leader>vp", "<cmd>Review qp<cr>", { desc = "Review: quick comments panel" })
vim.keymap.set("n", "<leader>ve", "<cmd>Review export<cr>", { desc = "Review: export markdown" })
vim.keymap.set("n", "<leader>vs", "<cmd>Review send<cr>", { desc = "Review: send to harness" })
vim.keymap.set("n", "<leader>vS", "<cmd>Review qs<cr>", { desc = "Review: send quick comments" })
vim.keymap.set("n", "<leader>vq", "<cmd>Review close<cr>", { desc = "Review: close" })
