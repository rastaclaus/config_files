export EDITOR=nvim
export TERM=xterm-256color
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"
export GOPATH="$HOME/projects/go"
eval "$(pyenv init --path)"
eval "$(pyenv virtualenv-init -)"
if [[ -n $VIRTUAL_ENV && -e "${VIRTUAL_ENV}/bin/activate" ]]; then
  source "${VIRTUAL_ENV}/bin/activate"
fi
