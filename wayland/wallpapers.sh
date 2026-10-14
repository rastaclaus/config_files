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
#
# The output list is a readiness guard (do not run before a session exists);
# the single swaybg below then applies to all outputs by itself.
#
# Do not trust the mere presence of SWAYSOCK/NIRI_SOCKET: a stale SWAYSOCK can
# linger in the systemd user environment after a sway session (sway imports it
# and never unsets it; niri-session's `import-environment` then pulls it back
# in), which would make us pick the wrong compositor and print a scary
# "Unable to connect" error at startup. Require the socket to actually exist.
if [[ -n "${NIRI_SOCKET:-}" && -S "${NIRI_SOCKET}" ]]; then
    # niri reports an output as active when it is mapped to a logical output;
    # an unmapped/disabled output has "logical": null (there is no "active" key).
    mapfile -t outputs < <(niri msg --json outputs | jq -r 'to_entries[] | select(.value.logical != null) | .key')
elif [[ -n "${SWAYSOCK:-}" && -S "${SWAYSOCK}" ]]; then
    mapfile -t outputs < <(swaymsg -t get_outputs | jq -r '.[] | select(.active) | .name')
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

# A single swaybg with no -o applies the image to every output (including ones
# plugged in later). Unlike one process per output, it does not log
# "Could not find config for output ..." for the outputs it was not told about.
#
# swaybg's chatter is captured so it does not flash across the console at
# login; it is shown only if swaybg fails to come up.
log="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/wallpapers.log"
swaybg -i "$image" --mode fill >"$log" 2>&1 &
sbg=$!

sleep 0.3
if ! kill -0 "$sbg" 2>/dev/null; then
    cat "$log" >&2
    exit 1
fi
