-- Тема Neovim следует за ~/.local/state/dotfiles/background-mode.
--
-- Раньше уже запущенные Neovim переключал внешний nvim-ctrl из
-- wayland/theme-sync, но он требует сокета (`--listen`/serverstart), а бинарник
-- nvim-ctrl в репозитории нигде не устанавливался — ветка молча не работала.
-- Поэтому watcher живёт внутри Neovim: следим за каталогом state (а не за
-- файлом: так переживаем атомарную замену/rename) и переигрываем colorscheme.
--
-- gruvbox.nvim читает vim.o.background только в load() (OptionSet он не
-- слушает), поэтому после смены background нужен повторный :colorscheme.
local M = {}

local dir = vim.fn.expand("~/.local/state/dotfiles")
local file = dir .. "/background-mode"
local debounce_ms = 80

local function read_mode()
	local f = io.open(file, "r")
	if not f then
		return nil
	end
	local mode = (f:read("*l") or ""):gsub("%s", "")
	f:close()
	return (mode == "dark" or mode == "light") and mode or nil
end

function M.apply(mode)
	if not mode or vim.o.background == mode then
		return
	end
	vim.o.background = mode
	-- vim.g.colors_name выставляет сам :colorscheme; fallback — наша тема.
	vim.cmd.colorscheme(vim.g.colors_name or "gruvbox")
end

function M.start()
	if M.started then
		return
	end
	M.started = true

	M.apply(read_mode())

	local uv = vim.uv or vim.loop
	M.timer = uv.new_timer()

	local function kick()
		-- За одно переключение темы в каталоге меняется несколько файлов,
		-- поэтому склеиваем события.
		M.timer:start(debounce_ms, 0, vim.schedule_wrap(function()
			M.apply(read_mode())
		end))
	end

	M.handle = uv.new_fs_event()
	local ok = pcall(uv.fs_event_start, M.handle, dir, {}, kick)
	if not ok then
		-- ФС без inotify (или watch на каталог не удался): опрашиваем файл.
		M.handle = nil
		M.poll = uv.new_fs_poll()
		pcall(uv.fs_poll_start, M.poll, kick, file, 1000)
	end

	vim.api.nvim_create_autocmd("VimLeavePre", {
		once = true,
		callback = function()
			if M.handle then
				pcall(M.handle.stop, M.handle)
				pcall(M.handle.close, M.handle)
				M.handle = nil
			end
			if M.poll then
				pcall(M.poll.stop, M.poll)
				pcall(M.poll.close, M.poll)
				M.poll = nil
			end
			if M.timer then
				pcall(M.timer.stop, M.timer)
				pcall(M.timer.close, M.timer)
				M.timer = nil
			end
		end,
	})
end

return M
