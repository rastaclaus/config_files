function fzf-git-log --description "Вставить полные хеши коммитов, выбранных через fzf"
    if not command git rev-parse --git-dir >/dev/null 2>&1
        echo 'fzf-git-log: не git-репозиторий' >&2
        return 1
    end

    set -lx SHELL (command -v fish)

    set -l selected (
        # --no-show-signature: подписи ломают разбор строки (в них пробелы).
        command git log --no-show-signature --color=always \
            --date=short \
            --format='%C(bold blue)%h%C(reset) %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)' |
        fzf --ansi \
            --multi \
            --prompt='Git Log> ' \
            --query=(commandline --current-token) \
            --preview='command git show --color=always --stat --patch {1}' \
            --preview-window=wrap
    ) || return 1

    set -l hashes
    for line in $selected
        # Первое поле строки — сокращённый хеш; разворачиваем его до полного.
        set -l short (string split --field 1 -- ' ' $line)
        # `--` тут нельзя: git печатает его отдельной строкой (`--`, хеш).
        set -a hashes (command git rev-parse --verify --quiet "$short^{commit}")
    end

    commandline --current-token --replace -- (string join ' ' $hashes)
    commandline --function repaint
end
