function fzf-git-status --description "Вставить пути изменённых файлов, выбранных через fzf"
    if not command git rev-parse --git-dir >/dev/null 2>&1
        echo 'fzf-git-status: не git-репозиторий' >&2
        return 1
    end

    # fzf выполняет --preview через $SHELL; здесь нужен fish, потому что
    # в превью используется `string sub`.
    set -lx SHELL (command -v fish)

    set -l selected (
        # color.status=always — иначе git не красит вывод в пайп, а fzf --ansi
        # без цветов нечего показывать.
        command git -c color.status=always status --short |
        fzf --ansi \
            --multi \
            --nth=2.. \
            --prompt='Git Status> ' \
            --query=(commandline --current-token) \
            --preview='git-status-preview {}' \
            --preview-window=wrap
    ) || return 1

    set -l paths
    for line in $selected
        # status --short: "XY путь", у переименования — "XY старый -> новый".
        set -l path (string sub --start=4 -- $line)
        set -a paths (string split -- '-> ' $path)[-1]
    end

    commandline --current-token --replace -- (string join ' ' $paths)
    commandline --function repaint
end
