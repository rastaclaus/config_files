# Тема fish следует за ~/.local/state/dotfiles/background-mode.
# Раньше это делал darkman через universal background_mode; universal-переменные
# больше не используем, чтобы fish не писал в репозиторий.
function __dotfiles_apply_theme --description 'Apply dark/light fish theme'
    set -l mode_file $HOME/.local/state/dotfiles/background-mode
    test -r $mode_file; or return 0
    set -l mode (string trim -- (command cat $mode_file 2>/dev/null))
    test "$mode" = "$__dotfiles_theme_mode"; and return 0
    switch $mode
        case dark
            fish_config theme choose dark
            set -g __dotfiles_theme_mode dark
        case light
            fish_config theme choose "Snow Day"
            set -g __dotfiles_theme_mode light
    end
end
