function zmx-select --description 'Выбор сессии zmx через fzf: Enter — attach, Ctrl-N — создать'
    if not type -q zmx
        echo 'zmx-select: zmx не найден' >&2
        return 1
    end
    if not type -q fzf
        echo 'zmx-select: fzf не найден' >&2
        return 1
    end

    # Сессии в виде "имя  pid:N  clients:N  <дата>" для fzf.
    # `zmx list` отдаёт таб-раздельные key=value (name/pid/clients/created/cwd),
    # у текущей сессии перед name — префикс "→ ", у остальных — два пробела.
    set -l display
    for line in (zmx list 2>/dev/null)
        set -l fields (string split \t -- $line)
        set -l name (string match -r "name=\K.*" -- $fields[1])
        test -n "$name"; or continue
        set -l clients (string match -r "clients=\K.*" -- $fields[3])
        set -l created (string match -r "created=\K.*" -- $fields[4])
        set -l when ""
        if test -n "$created"
            set when (date -d @$created "+%m-%d %H:%M" 2>/dev/null)
        end
        set -a display (printf '%-20s  clients:%-2s  %s' $name $clients $when)
    end

    set -l output
    if test -n "$display"
        set output (
            string join \n -- $display | fzf \
                --print-query \
                --expect=ctrl-n \
                --height=80% \
                --reverse \
                --prompt='zmx> ' \
                --header='Enter: attach | Ctrl-N: create new' \
                --preview='zmx history {1}' \
                --preview-window=right:60%:follow
        )
    else
        # Сессий нет: fzf без списка, только ввод имени новой сессии.
        set output (
            fzf \
                --print-query \
                --expect=ctrl-n \
                --height=80% \
                --reverse \
                --prompt='zmx (new)> ' \
                --header='Enter/Ctrl-N: create session' \
                --no-info
        )
    end
    if test $status -ne 0
        return 130 # Esc/ctrl-c в пикере — остаться в обычном shell
    end

    set -l query $output[1]
    set -l key $output[2]
    set -l selected $output[3]

    set -l session_name
    if test "$key" = ctrl-n; and test -n "$query"
        set session_name $query
    else if test -n "$selected"
        # Первое поле строки списка — имя сессии
        set session_name (string split --max 1 -- '  ' $selected)[1]
    else if test -n "$query"
        set session_name $query
    else
        return 130
    end

    # attach — это upsert: создаст сессию, если её ещё нет
    zmx attach $session_name
end
