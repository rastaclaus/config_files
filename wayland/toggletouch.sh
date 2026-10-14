#!/usr/bin/env bash
#
# Toggle the touchpad on/off. Works under both sway and niri.
#
# On niri it first tries the built-in "toggle-touchpad" action; releases before
# that action existed fall back to rewriting an optional include file, which
# niri live-reloads. On sway it flips the libinput send_events state for the
# first touchpad found.
set -euo pipefail

if [[ -n "${NIRI_SOCKET:-}" ]]; then
    if niri msg action toggle-touchpad >/dev/null 2>&1; then
        exit 0
    fi

    # Fallback: niri watches this optional include and reloads on change.
    override="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/50-touchpad.kdl"
    mkdir -p "$(dirname "$override")"
    if grep -q off "$override" 2>/dev/null; then
        : >"$override"
        notify-send "Touchpad enabled"
    else
        printf 'input {\n    touchpad {\n        off\n    }\n}\n' >"$override"
        notify-send "Touchpad disabled"
    fi
    exit 0
fi

if [[ -z "${SWAYSOCK:-}" ]]; then
    notify-send "Touchpad" "Neither sway nor niri is running"
    exit 1
fi

id="${1:-}"
if [[ -z "$id" ]]; then
    id="$(swaymsg -t get_inputs | jq -r '.[] | select(.type == "touchpad") | .identifier' | head -n1)"
fi

if [[ -z "$id" ]]; then
    notify-send "Touchpad" "No touchpad found"
    exit 1
fi

state="$(swaymsg -t get_inputs \
    | jq -r --arg id "$id" '.[] | select(.identifier == $id) | .libinput.send_events // "enabled"')"

if [[ "$state" == "enabled" ]]; then
    swaymsg input "$id" events disabled
    notify-send "Touchpad disabled"
else
    swaymsg input "$id" events enabled
    notify-send "Touchpad enabled"
fi
