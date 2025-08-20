if status is-interactive
    if [ -z $DISPLAY ] && [ "$(tty)" = /dev/tty1 ]
        then
        exec sway
    end

end

pyenv init - fish | source
direnv hook fish | source

fish_vi_key_bindings

set -x PROVIDER1_API_KEY (cat $HOME/.config/provider1_key)
set -x OPENAI_API_KEY (cat $HOME/.config/provider1_key)
set -x PROVIDER3_API_KEY (cat $HOME/.config/provider3_key)
