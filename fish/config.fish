# EDITOR раньше жил в universal-переменных fish; теперь — здесь.
set -gx EDITOR /usr/bin/nvim

# Key bindings: содержимое бывшего conf.d/fish_frozen_key_bindings.fish.
set -g fish_key_bindings fish_vi_key_bindings
set -e -U fish_key_bindings 2>/dev/null

set -gx PYENV_ROOT $HOME/.pyenv
fish_add_path -g $HOME/.local/bin $HOME/.cargo/bin

pyenv init - fish | source
direnv hook fish | source

set -x BOTHUB_API_KEY (cat $HOME/.config/openai_key)
set -x OPENAI_API_KEY (cat $HOME/.config/openai_key)
set -x NTECH_API_KEY (cat $HOME/.config/ntech_key)
set -x ROUTERAI_API_KEY (cat $HOME/.config/router_ai_key)

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
