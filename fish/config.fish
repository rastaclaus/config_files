if status is-interactive
    if [ -z $DISPLAY ] && [ "$(tty)" = /dev/tty1 ]
        then
        exec sway
    end

end

pyenv init - fish | source
direnv hook fish | source

fish_vi_key_bindings

set -x BOTHUB_API_KEY (cat $HOME/.config/openai_key)
set -x OPENAI_API_KEY (cat $HOME/.config/openai_key)
set -x NTECH_API_KEY (cat $HOME/.config/ntech_key)
