#!/usr/bin/env bash
#
# Kitty: перечитать конфиг (SIGUSR1).
#
# Обычное переключение light/dark kitty делает сам: файлы авто-темы
# (~/.config/kitty/{dark,light}-theme.auto.conf) применяются по схеме ОС из
# xdg-desktop-portal (org.freedesktop.appearance color-scheme; на этом десктопе
# её отдаёт darkman), и на смену схемы kitty перекрашивает окна без этого хука.
#
# Хук нужен для другого: SIGUSR1 перечитывает конфиг целиком и заново
# применяет авто-тему, поэтому он подхватывает правки *-theme.auto.conf и любые
# изменённые ключи kitty.conf в уже открытых окнах, а также служит страховкой,
# если портала нет (запуск вне сессии, сломанный dconf).
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

theme_have kitty || exit 0
theme_running kitty || exit 0

pkill -USR1 -x kitty 2>/dev/null || true
theme_log "kitty: SIGUSR1 ($mode)"
