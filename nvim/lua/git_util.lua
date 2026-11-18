-- Общие git-запросы для diffview и review.nvim.
-- Корень берём у текущего буфера, иначе у cwd: в служебных буферах
-- (review-таб, панели diffview) имени файла нет.
local M = {}

local function git(args)
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
-- Сравнение с merge-base, а не с кончиком базовой ветки: чужие коммиты,
-- приехавшие в main после ответвления, в ревью не попадают.
function M.branch_point()
	local base = base_branch()
	if not base then
		return nil
	end
	return git({ "merge-base", base, "HEAD" })
end

return M
