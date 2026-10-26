function git-status-preview --description "Превью для fzf-git-status: дифф файла из строки git status --short"
    # На вход приходит строка "XY путь" или "XY старый -> новый".
    set -l path (string replace -r '^.* -> ' '' -- (string sub --start=4 -- $argv[1]))
    set -l path (string unescape -- $path)

    if command git ls-files --error-unmatch -- $path >/dev/null 2>&1
        command git diff --color=always -- $path
    else
        # untracked: диффа нет, показываем начало файла
        command head -n 200 -- $path
    end
end
