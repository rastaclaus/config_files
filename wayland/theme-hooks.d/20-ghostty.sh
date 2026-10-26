#!/usr/bin/env bash
#
# Ghostty: перечитать конфиг (SIGUSR2).
#
# Обычное переключение light/dark ghostty делает сам: `theme =
# light:...,dark:...` следует за gsettings color-scheme, который выставляет
# 10-gtk.sh, а на смену схемы ghostty отвечает внутренним reload (см.
# App.colorSchemeEvent -> reload_config). Проверено на 1.3.1: окно меняет фон
# без этого хука.
#
# Хук нужен для другого: SIGUSR2 перечитывает конфиг целиком, поэтому он
# подхватывает правки ghostty/themes/* и любые изменённые ключи в уже открытых
# окнах, а также служит страховкой, если libadwaita не увидел схему (нет
# dconf/портала).
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

theme_have ghostty || exit 0
theme_running ghostty || exit 0

pkill -USR2 -x ghostty 2>/dev/null || true
theme_log "ghostty: SIGUSR2 ($mode)"
