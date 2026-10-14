#!/usr/bin/env bash
#
# Set a random wallpaper on every active output.
#
# Works under both sway (via swaymsg) and niri (via niri msg). Wallpapers are
# drawn with swaybg, which runs on both compositors.
#
# Override the directory with WALLPAPER_DIR=<path>.
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Wallpapers}"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "wallpapers: no such directory: $WALLPAPER_DIR" >&2
    exit 1
fi

mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

if (( ${#images[@]} == 0 )); then
    echo "wallpapers: no images found in $WALLPAPER_DIR" >&2
    exit 1
fi

# Detect the running compositor and list its active outputs.
if [[ -n "${SWAYSOCK:-}" ]]; then
    mapfile -t outputs < <(swaymsg -t get_outputs | jq -r '.[] | select(.active) | .name')
elif [[ -n "${NIRI_SOCKET:-}" ]]; then
    mapfile -t outputs < <(niri msg --json outputs | jq -r 'to_entries[] | select(.value.active == true) | .key')
else
    echo "wallpapers: neither sway nor niri is running" >&2
    exit 1
fi

if (( ${#outputs[@]} == 0 )); then
    echo "wallpapers: no active outputs" >&2
    exit 1
fi

image="${images[RANDOM % ${#images[@]}]}"

pkill -x swaybg 2>/dev/null || true

for output in "${outputs[@]}"; do
    swaybg -o "$output" -i "$image" --mode fill &
done
