if command -q darkman
    if test (darkman get) = "light"
        fish_config theme choose "Snow Day"
    else
        fish_config theme choose "dark"
    end
end

pyenv init - fish | source
direnv hook fish | source

set -x PROVIDER1_API_KEY (cat $HOME/.config/provider1_key)
set -x OPENAI_API_KEY (cat $HOME/.config/provider1_key)
set -x PROVIDER3_API_KEY (cat $HOME/.config/provider3_key)
set -x PROVIDER2_API_KEY (cat $HOME/.config/provider2_key)

if status is-interactive
    if [ -z $DISPLAY ] && [ "$(tty)" = /dev/tty1 ]
        exec sway
    end
end
