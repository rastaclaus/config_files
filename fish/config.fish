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

if status is-interactive
    if [ -z $DISPLAY ] && [ "$(tty)" = /dev/tty1 ]
        exec sway
    end
end

