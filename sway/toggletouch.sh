#!/usr/bin/env bash
#
# Toggle the touchpad on/off. Pass an input identifier as $1 to target a
# specific touchpad, otherwise the first touchpad is used.
set -euo pipefail

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
