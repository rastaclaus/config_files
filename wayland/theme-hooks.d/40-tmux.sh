#!/usr/bin/env bash
#
# tmux (>= 3.8): alacritty отвечает на OSC 11, но не поддерживает DECSET 2031,
# поэтому после смены палитры уже подключённый клиент не узнаёт о новой теме
# сам. Форсируем режим явно; на старых tmux такой опции нет — глушим ошибку.
#
# list-sessions не даёт поднять сервер, если tmux сейчас не запущен.
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

theme_have tmux || exit 0
tmux list-sessions >/dev/null 2>&1 || exit 0

tmux set -s theme "$mode" 2>/dev/null || true
# Строка статуса перерисовывается сразу; содержимое панелей — забота
# приложений внутри (см. 60-redraw.sh).
tmux refresh-client -S 2>/dev/null || true
theme_log "tmux: theme=$mode"
