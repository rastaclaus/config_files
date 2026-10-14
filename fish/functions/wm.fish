function wm --description 'Select the Wayland compositor (sway|niri) for the console session'
    if test (count $argv) -ne 1
        echo "usage: wm sway|niri"
        set -q WAYLAND_COMPOSITOR; and echo "current: $WAYLAND_COMPOSITOR"
        return 1
    end

    switch $argv[1]
        case sway niri
            set -Ux WAYLAND_COMPOSITOR $argv[1]
            echo "WAYLAND_COMPOSITOR = $argv[1] (takes effect on next login)"
        case '*'
            echo "wm: unknown compositor '$argv[1]' (use sway or niri)" >&2
            return 1
    end
end
