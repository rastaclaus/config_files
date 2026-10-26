#!/usr/bin/env bash
#
# Mattermost Desktop: тема чата (серверный user preference) + тема окна
# (darkMode и trayIconTheme в config.json). Скрипт сам перезапускает приложение;
# если его нет, тихо выходит.
#
# Перезапуск делаем только при реальной смене режима: verify.sh и повторное
# применение текущей темы не должны дёргать приложение.
#
# THEME_SYNC_NO_MATTERMOST=1 — не перезапускать (пробрасывается из theme-sync).
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

[[ -z "${THEME_SYNC_NO_MATTERMOST:-}" ]] || exit 0
[[ ${THEME_PREV_MODE:-} != "$mode" ]] || exit 0
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/Mattermost/config.json" ]] || exit 0

# Приложению нужна живая графическая сессия, а не IPC композитора, поэтому
# проверяем wayland/X11-сокет.
theme_gui || exit 0

"$REPO/wayland/mattermost-theme" "$mode" || true
theme_log "mattermost: restarted ($mode)"
