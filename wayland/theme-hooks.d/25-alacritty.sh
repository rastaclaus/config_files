#!/usr/bin/env bash
#
# Alacritty: отправить новую палитру и прозрачность уже запущенным окнам.
#
# live_config_reload следит только за основным конфигом, изменения
# импортированных файлов он НЕ замечает (проверено на 0.1x через IPC:
# get-config не меняется после правки state). Поэтому палитру, цвета
# выделения и opacity передаём через `alacritty msg config`.
#
# darkman вызывается как systemd user service без ALACRITTY_SOCKET, поэтому
# перебираем все сокеты запущенных процессов в $XDG_RUNTIME_DIR и /tmp.
# Новые окна читают state сами через import.
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

theme_have alacritty || exit 0

state="$(theme_state_dir)"
palette=$(sed -n 's/^import = \["\(.*\)"\]$/\1/p' "$state/alacritty.toml" | tail -n 1)
palette=${palette/#\~/$HOME}
opacity=$(sed -n 's/^opacity *= *//p' "$state/alacritty.toml" | head -n 1)
[[ -r $palette ]] || exit 0

config_args=$(awk -F"'" '
    /^\[/ { section = "" }
    /^\[colors\./ { section = $0; gsub(/^\[|\]$/, "", section); next }
    section != "" && /^[a-z_]+[ \t]*=/ {
        key = $1; gsub(/[ \t=]/, "", key);
        printf "%s.%s=\"%s\" ", section, key, $2;
    }
' "$palette")
config_args="$config_args window.opacity=${opacity:-1.0}"

shopt -s nullglob
sockets=( "${XDG_RUNTIME_DIR:-/run/user/$UID}"/Alacritty*.sock /tmp/Alacritty*.sock )
shopt -u nullglob

applied=0
# shellcheck disable=SC2086 # нужен word splitting для аргументов config
if [[ ${#sockets[@]} -gt 0 ]]; then
    for sock in "${sockets[@]}"; do
        [[ -S "$sock" ]] || continue
        env -u ALACRITTY_SOCKET alacritty msg -s "$sock" config -w -1 $config_args 2>/dev/null || true
        applied=1
    done
elif alacritty msg get-config >/dev/null 2>&1; then
    alacritty msg config -w -1 $config_args 2>/dev/null || true
    applied=1
fi

(( applied )) || theme_log "alacritty: no running instance"
