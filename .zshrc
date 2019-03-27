# The following lines were added by compinstall

autoload -U compinit promptinit
compinit
promptinit
prompt walters

HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
unsetopt beep
bindkey -v
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh
