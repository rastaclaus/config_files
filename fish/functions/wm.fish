function wm --description 'Select the Wayland compositor (sway|niri|none) for the console session'
    set -l state $HOME/.local/state/dotfiles/compositor

    if test (count $argv) -ne 1
        echo "usage: wm sway|niri|none"
        test -r $state; and echo "current: "(string trim -- (command cat $state))
        return 1
    end

    switch $argv[1]
        case sway niri none
            mkdir -p (path dirname $state)
            printf '%s\n' $argv[1] > $state
            # legacy: раньше выбор жил здесь, теперь источник истины — state
            set -e -U WAYLAND_COMPOSITOR 2>/dev/null
            echo "$argv[1] (takes effect on next login)"
        case '*'
            echo "wm: unknown compositor '$argv[1]' (use sway, niri or none)" >&2
            return 1
    end
end
