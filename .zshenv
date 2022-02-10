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

export CLUTTER_BACKEND=wayland
export SDL_VIDEODRIVER=wayland
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export MOZ_ENABLE_WAYLAND=1
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export WLR_NO_HARDWARE_CURSORS=1
