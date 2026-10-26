#!/usr/bin/env bash
#
# fish уже подхватывает тему на следующем промпте (fish/conf.d/theme.fish
# вызывается из fish_prompt), но уже нарисованный промпт остаётся старым.
# SIGWINCH заставляет fish перерисовать командную строку и заново выполнить
# fish_prompt — при условии, что включён fish_handle_reflow (см.
# fish/conf.d/theme.fish).
#
# SIGUSR1 слать нельзя: без обработчика это дефолтное действие «убить
# процесс». SIGWINCH по умолчанию игнорируется и безопасен.
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

theme_running fish || exit 0

pkill -WINCH -x fish 2>/dev/null || true
theme_log "fish: SIGWINCH ($mode)"
