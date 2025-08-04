if status is-interactive
    # Commands to run in interactive sessions can go here
end
pyenv init  - fish | source
direnv hook fish | source

set -x PROVIDER1_API_KEY (cat $HOME/.config/provider1_key)
set -x OPENAI_API_KEY (cat $HOME/.config/provider1_key)
set -x PROVIDER3_API_KEY (cat $HOME/.config/provider3_key)
