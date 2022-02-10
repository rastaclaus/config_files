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
export GBM_BACKEND=nvidia-drm
export GDK_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export SDL_VIDEODRIVER=wayland
export WLR_NO_HARDWARE_CURSORS=1
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_TYPE=wayland
export __GLX_VENDOR_LIBRARY_NAME=nvidia
