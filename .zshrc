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
bindkey -v
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

eval "$(pyenv init -)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

