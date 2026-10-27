# EDITOR раньше жил в universal-переменных fish; теперь — здесь.
set -gx EDITOR /usr/bin/nvim

# Key bindings: содержимое бывшего conf.d/fish_frozen_key_bindings.fish.
set -g fish_key_bindings fish_vi_key_bindings
set -e -U fish_key_bindings 2>/dev/null

# В vi-режиме fish вешает ctrl-r на `redo` (как Vim), а поиск по истории — на
# `/` в insert mode. Возвращаем привычный ctrl-r: нативный пейджер истории.
# Он умеет то же ядро, что и раньше fzf.fish (refine запроса, ctrl-r — старше,
# ctrl-s — новее), но не требует ни плагина, ни сети при установке.
bind ctrl-r history-pager
bind -M insert ctrl-r history-pager

# Из fzf.fish оставлены только те два поиска, у которых нет нативной замены;
# файлы/процессы/переменные закрываются tab-комплишном fish.
if status is-interactive
    bind ctrl-alt-s fzf-git-status
    bind ctrl-alt-l fzf-git-log
    bind -M insert ctrl-alt-s fzf-git-status
    bind -M insert ctrl-alt-l fzf-git-log
end

set -gx PYENV_ROOT $HOME/.pyenv
fish_add_path -g $HOME/.local/bin $HOME/.cargo/bin

pyenv init - fish | source
direnv hook fish | source

# Внутренние (рабочие) endpoint'ы и ключи живут вне репозитория:
# ~/.config/internal.env, по строке KEY=value без кавычек. Так в репозитории
# не остаётся ни адресов, ни имён файлов с ключами. Файла нет — переменные
# просто не задаются.
if test -r $HOME/.config/internal.env
    for line in (string match -rv '^\s*(#|$)' < $HOME/.config/internal.env)
        set -gx (string split -m1 = -- $line)
    end
end

if status is-interactive
    if test -z "$DISPLAY"; and test -z "$WAYLAND_DISPLAY"; and test "$(tty)" = /dev/tty1
        # Какой композитор поднимать, решает установщик (install/hosts.conf) и
        # команда `wm`; значение живёт в state, а не в universal-переменных.
        set -l comp sway
        set -l comp_file $HOME/.local/state/dotfiles/compositor
        if test -r $comp_file
            set comp (string trim -- (command cat $comp_file 2>/dev/null))
        end
        switch $comp
            case none
                # headless-хост: композитора нет намеренно
            case niri
                if command -q niri-session
                    exec niri-session
                end
                echo "dotfiles: niri-session не найден; остаюсь в shell" >&2
            case sway
                if command -q sway
                    exec sway
                end
                echo "dotfiles: sway не найден; остаюсь в shell" >&2
            case '*'
                echo "dotfiles: неизвестный compositor '$comp' в $comp_file" >&2
        end
    end
end
