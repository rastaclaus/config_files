#!/usr/bin/env bash
#
# Helix перечитывает конфиг и тему по SIGUSR1.
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

# Имя процесса — helix (hx — это симлинк на тот же бинарник, но запущенный
# через него процесс всё равно называется helix).
theme_running helix || exit 0

pkill -USR1 -x helix 2>/dev/null || true
theme_log "helix: SIGUSR1 ($mode)"
