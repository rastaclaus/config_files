export EDITOR=nvim
export TERM=xterm-256color
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
