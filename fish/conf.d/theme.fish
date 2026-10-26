# Тема fish следует за ~/.local/state/dotfiles/background-mode.
# Раньше это делал darkman через universal background_mode; universal-переменные
# больше не используем, чтобы fish не писал в репозиторий.
#
# Имена тем — по файлам fish/themes/{dark,light}.theme. Цвета промпта там
# заданы hex-значениями: именованные (green/brgreen/red) рисуются палитрой
# терминала и на headless-хосте не меняются вместе с темой.

# fish 4.x по умолчанию не перерисовывает командную строку при SIGWINCH в
# терминалах, которые сами переносят текст (alacritty, ghostty). Из-за этого
# уже нарисованный промпт остаётся в старой теме до следующего Enter.
# wayland/theme-hooks.d/50-fish.sh шлёт SIGWINCH, а без этой переменной
# обработчик fish его игнорирует. Цена: промпт перерисовывается и при обычном
# ресайзе окна.
set -g fish_handle_reflow 1

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
            fish_config theme choose light
            set -g __dotfiles_theme_mode light
    end
end
