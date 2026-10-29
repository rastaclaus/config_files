-- Ревью всей ветки в отдельном табе: панель файлов + полноценные diff-буферы.
-- gitsigns остаётся для мелких правок, это — для просмотра того, что накопилось
-- с момента ответвления от базовой ветки.
-- Отдельно — «рабочий» режим (:DiffviewOpen без аргументов): стейджинг файлов
-- по `s` в панели и merge-tool для конфликтов rebase/merge.
require("diffview").setup({
	enhanced_diff_hl = true, -- подсветка «что именно поменялось внутри строки»
})

local function git(args)
	-- Считаем от корня репозитория текущего буфера, а не от cwd: в nvim может
	-- быть открыт другой проект.
	local cwd = vim.fs.root(0, ".git") or vim.fn.getcwd()
	local cmd = { "git", "-C", cwd }
	vim.list_extend(cmd, args)
	local out = vim.fn.systemlist(cmd)
	if vim.v.shell_error ~= 0 then
		return nil
	end
	return out[1]
end

-- Базовая ветка: сначала origin/HEAD (сам определяет main/master), потом перебор.
local function base_branch()
	local head = git({ "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })
	if head and head ~= "" then
		return head
	end
	for _, name in ipairs({ "origin/main", "origin/master", "main", "master" }) do
		if git({ "rev-parse", "--verify", "--quiet", name }) then
			return name
		end
	end
end

-- Точка ответвления: merge-base базовой ветки и HEAD.
local function branch_point()
	local base = base_branch()
	if not base then
		return nil
	end
	return git({ "merge-base", base, "HEAD" })
end

-- Сравнение с merge-base, а не с кончиком базовой ветки: чужие коммиты,
-- приехавшие в main после ответвления, в ревью не попадают.
-- Передаём SHA, поэтому в дифф входит и незакоммиченное рабочее дерево.
vim.keymap.set("n", "<leader>gm", function()
	local sha = branch_point()
	if not sha then
		vim.notify(
			"diffview: базовая ветка не найдена (origin/HEAD, main, master)",
			vim.log.levels.WARN
		)
		return
	end
	vim.cmd("DiffviewOpen " .. sha)
end, { desc = "Review branch since branch point" })

-- История ветки от той же точки: только коммиты, без рабочего дерева.
vim.keymap.set("n", "<leader>gM", function()
	local sha = branch_point()
	if not sha then
		vim.notify(
			"diffview: базовая ветка не найдена (origin/HEAD, main, master)",
			vim.log.levels.WARN
		)
		return
	end
	vim.cmd("DiffviewFileHistory --range=" .. sha .. "..HEAD")
end, { desc = "Branch commits since branch point" })

-- «Рабочий» режим: индекс vs рабочее дерево. Здесь (и только здесь) работает
-- `s` в панели — стейдж/анстейдж, а при merge/rebase конфликты открываются
-- merge-tool'ом (OURS | LOCAL | THEIRS). С rev-аргументом (как в <leader>gm)
-- diffview стейджить отказывается — там левая сторона COMMIT, а не STAGE.
vim.keymap.set("n", "<leader>go", ":DiffviewOpen<CR>", { desc = "Diffview: working tree (stage / conflicts)" })

vim.keymap.set("n", "<leader>gq", ":DiffviewClose<CR>", { desc = "Diffview: close" })

-- Продолжить rebase и обновить diffview. GIT_EDITOR=true — берём сохранённое
-- сообщение коммита, иначе git попытается запустить редактор внутри vim.system.
-- Корень берём у текущей diffview-вьюхи: в панели буфер не файловый, и
-- vim.fs.root по нему ничего не найдёт.
vim.keymap.set("n", "<leader>gc", function()
	local ok, view = pcall(function()
		return require("diffview.lib").get_current_view()
	end)
	local root = (ok and view and view.adapter and view.adapter.ctx.toplevel)
		or vim.fs.root(0, ".git")
		or vim.fn.getcwd()

	vim.system({ "git", "-C", root, "rebase", "--continue" }, { env = { GIT_EDITOR = "true" } }, function(out)
		vim.schedule(function()
			local text = vim.trim((out.stdout or "") .. "\n" .. (out.stderr or ""))
			if out.code == 0 then
				vim.notify(text ~= "" and text or "rebase: продолжен", vim.log.levels.INFO)
			elseif text:find("CONFLICT") then
				vim.notify("rebase: следующий конфликт, резолвите дальше\n" .. text, vim.log.levels.WARN)
			else
				vim.notify("rebase --continue: " .. text, vim.log.levels.ERROR)
			end
			require("diffview").emit("refresh_files")
		end)
	end)
end, { desc = "Continue rebase and refresh diffview" })
