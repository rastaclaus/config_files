export EDITOR=nvim
export PATH="$HOME/.local/bin:$PATH"
export GOPATH="$HOME/projects/go"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

if [ -n "$PYTHONPATH" ]; then
    export PYTHONPATH='/home/artems/.local/pipx/venvs/pdm/lib/python3.10/site-packages/pdm/pep582':$PYTHONPATH
else
    export PYTHONPATH='/home/artems/.local/pipx/venvs/pdm/lib/python3.10/site-packages/pdm/pep582'
fi
