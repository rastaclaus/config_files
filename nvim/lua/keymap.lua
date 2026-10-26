-- Leader key
vim.g.mapleader = " " -- Set leader key to space
vim.g.maplocalleader = " " -- Set local leader key (NEW)

-- Buffer navigation
vim.keymap.set("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", { desc = "Previous buffer" })

-- Better window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
-- <C-L> в Neovim 0.13 — дефолтный маппинг, который кроме redraw делает
-- :nohlsearch, :diffupdate и снимает multicursor (:h CTRL-L-default,
-- :h mcursor-clear). Держим оба поведения: есть доп. курсоры — чистим,
-- иначе идём в правое окно.
local mc_ns = vim.api.nvim_create_namespace("nvim.multicursor")

vim.keymap.set("n", "<C-l>", function()
	if #vim.api.nvim_buf_get_extmarks(0, mc_ns, 0, -1, { limit = 1 }) > 0 then
		vim.cmd("nohlsearch")
		vim.cmd("diffupdate")
		vim.api.nvim_buf_clear_namespace(0, mc_ns, 0, -1)
		vim.cmd("normal! \12") -- перерисовать экран (raw <C-L>)
		return
	end
	vim.cmd("wincmd l")
end, { desc = "Clear multicursors / move to right window" })

-- Splitting & Resizing
vim.keymap.set("n", "<leader>sv", ":vsplit<CR>", { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>sh", ":split<CR>", { desc = "Split window horizontally" })
vim.keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })

-- Move lines up/down
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Better indenting in visual mode
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Quick file navigation
vim.keymap.set("n", "<leader>rc", ":e ~/.config/nvim/init.lua<CR>", { desc = "Edit config" })

-- Copy Full File-Path
vim.keymap.set("n", "<leader>pa", function()
	local path = vim.fn.expand("%:p")
	vim.fn.setreg("+", path)
	print("file:", path)
end)

-- Terminal keymap
vim.keymap.set("n", "<leader>tt", ":term<CR>", { noremap = true, silent = true, desc = "Toggle terminal" })
vim.keymap.set("t", "<ESC><ESC>", "<C-\\><C-N>", { noremap = true, silent = true, desc = "Term normal mode" })
vim.keymap.set("t", "<C-o>", "<C-\\><C-[>", { desc = "Alacritty normal mode" })

-- Tabs keymap
vim.keymap.set("n", "<leader>tn", ":tabnew<CR>", { desc = "New tab" })
vim.keymap.set("n", "<leader>tx", ":tabclose<CR>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>tm", ":tabmove<CR>", { desc = "Move tab" })
vim.keymap.set("n", "<leader>t>", ":tabmove +1<CR>", { desc = "Move tab right" })
vim.keymap.set("n", "<leader>t<", ":tabmove -1<CR>", { desc = "Move tab left" })

-- Function to open file in new tab
local function open_file_in_tab()
	vim.ui.input({ prompt = "File to open in new tab: ", completion = "file" }, function(input)
		if input and input ~= "" then
			vim.cmd("tabnew " .. input)
		end
	end)
end

-- Function to duplicate current tab
local function duplicate_tab()
	local current_file = vim.fn.expand("%:p")
	if current_file ~= "" then
		vim.cmd("tabnew " .. current_file)
	else
		vim.cmd("tabnew")
	end
end

-- Function to close tabs to the right
local function close_tabs_right()
	local current_tab = vim.fn.tabpagenr()
	local last_tab = vim.fn.tabpagenr("$")

	for i = last_tab, current_tab + 1, -1 do
		vim.cmd(i .. "tabclose")
	end
end

-- Function to close tabs to the left
local function close_tabs_left()
	local current_tab = vim.fn.tabpagenr()

	for i = current_tab - 1, 1, -1 do
		vim.cmd("1tabclose")
	end
end

vim.keymap.set("n", "<leader>tO", open_file_in_tab, { desc = "Open file in new tab" })
vim.keymap.set("n", "<leader>td", duplicate_tab, { desc = "Duplicate current tab" })
vim.keymap.set("n", "<leader>tr", close_tabs_right, { desc = "Close tabs to the right" })
vim.keymap.set("n", "<leader>tL", close_tabs_left, { desc = "Close tabs to the left" })

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(event)
		vim.keymap.set(
			"n",
			"<leader>q",
			vim.diagnostic.setloclist,
			{ buf = event.buf, desc = "Show diagnostic in loclist" }
		)
		vim.keymap.set("n", "<leader>d", function()
			vim.diagnostic.open_float()
		end, { buf = event.buf, desc = "Show diagnostic under cursor" })
	end,
})
-- Builtin completion (Neovim >= 0.12): <C-Space> triggers LSP completion,
-- falls back to 'omnifunc'/buffer completion when no server is attached.
-- <C-y> accepts, <C-e> cancels, <C-n>/<C-p> (or <Tab>/<S-Tab>) navigate.
vim.keymap.set("i", "<C-Space>", function()
	if #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
		vim.lsp.completion.get()
	else
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n", false)
	end
end, { desc = "Trigger completion" })
vim.keymap.set("i", "<Tab>", function()
	if vim.fn.pumvisible() == 1 then
		return "<C-n>"
	end
	return "<Tab>"
end, { expr = true, desc = "Next completion item" })
vim.keymap.set("i", "<S-Tab>", function()
	if vim.fn.pumvisible() == 1 then
		return "<C-p>"
	end
	return "<S-Tab>"
end, { expr = true, desc = "Previous completion item" })

