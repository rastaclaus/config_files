if command -q darkman
    if test (darkman get) = "light"
        fish_config theme choose "Snow Day"
    else
        fish_config theme choose "dark"
    end
end

pyenv init - fish | source
direnv hook fish | source

set -x BOTHUB_API_KEY (cat $HOME/.config/openai_key)
set -x OPENAI_API_KEY (cat $HOME/.config/openai_key)
set -x NTECH_API_KEY (cat $HOME/.config/ntech_key)
set -x ROUTERAI_API_KEY (cat $HOME/.config/router_ai_key)

if status is-interactive
    if test -z "$DISPLAY"; and test "$(tty)" = /dev/tty1
        # Pick the Wayland compositor for the console session.
        # Set it persistently with:  wm sway   |   wm niri
        set -q WAYLAND_COMPOSITOR; or set -Ux WAYLAND_COMPOSITOR sway
        switch $WAYLAND_COMPOSITOR
            case niri
                exec niri-session
            case '*'
                exec sway
        end
    end
end
