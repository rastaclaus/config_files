#!/usr/bin/env bash
#
# Разбудить TUI-приложения, которые перерисовываются по SIGWINCH и берут цвета
# из ANSI-палитры терминала. Это не «смена темы» приложений с hex-темами
# (yazi/lazygit/hx/nvim) — им нужен собственный reload, см. соседние
# хуки и docs/theme.md.
#
# Список приложений можно расширить через DOTFILES_THEME_REDRAW
# (разделённые пробелами имена процессов).
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

# fish обрабатывается отдельно (50-fish.sh): у него свой обработчик WINCH.
apps=( htop less ncdu )
# shellcheck disable=SC2206 # список из переменной — намеренный word splitting
apps+=( ${DOTFILES_THEME_REDRAW:-} )

signalled=""
for app in "${apps[@]}"; do
    [[ -n $app ]] || continue
    theme_running "$app" || continue
    pkill -WINCH -x "$app" 2>/dev/null || true
    signalled+=" $app"
done

if [[ -n $signalled ]]; then
    theme_log "redraw:$signalled ($mode)"
fi
