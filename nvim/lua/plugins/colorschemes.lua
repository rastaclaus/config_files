-- Фон берём из state-файла, который пишет wayland/theme-sync.
local mode_file = vim.fn.expand("~/.local/state/dotfiles/background-mode")
local f = io.open(mode_file, "r")
if f then
	local mode = f:read("*l")
	f:close()
	if mode == "light" or mode == "dark" then
		vim.o.background = mode
	end
end

vim.cmd.colorscheme("gruvbox")
