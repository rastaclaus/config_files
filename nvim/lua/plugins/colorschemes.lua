-- Фон берётся из state-файла, который пишет wayland/theme-sync.
-- theme.start() применяет режим при старте и дальше следит за файлом, чтобы
-- уже открытые Neovim переключались без внешних сигналов (см. lua/theme.lua).
require("theme").start()

vim.cmd.colorscheme("gruvbox")
