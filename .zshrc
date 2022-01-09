# The following lines were added by compinstall

fpath=(~/.zsh/completion $fpath)
autoload -U compinit promptinit
compinit
promptinit
prompt walters
#
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
#
unsetopt beep
setopt HIST_IGNORE_DUPS
#
bindkey -v
#
source /usr/share/fzf/key-bindings.zsh
source /usr/share/doc/pkgfile/command-not-found.zsh
source /usr/share/fzf/completion.zsh
#
eval "$(direnv hook zsh)"
