source ~/.config/zsh/plugins/zsh-snap/znap.zsh
# The following lines were added by compinstall

fpath=(~/.zsh/completion $fpath)
autoload -U compinit promptinit
compinit
promptinit
prompt walters

HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000

unsetopt beep
setopt HIST_IGNORE_DUPS

bindkey -v

source /usr/share/fzf/key-bindings.zsh
source /usr/share/doc/pkgfile/command-not-found.zsh
source /usr/share/fzf/completion.zsh

eval "$(direnv hook zsh)"

if [[ -n $VIRTUAL_ENV && -e "${VIRTUAL_ENV}/bin/activate" ]]; then
  source "${VIRTUAL_ENV}/bin/activate"
fi

if [ -n "$DESKTOP_SESSION" ];then
    eval $(gnome-keyring-daemon --start)
    export SSH_AUTH_SOCK
fi

eval "$(pyenv init -)"

alias ssh="TERM=xterm-256color ssh"
