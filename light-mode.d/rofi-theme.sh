#!/bin/sh
# rofi theme for light mode.
CONFIG="$HOME/.config/rofi/config.rasi"
[ -f "$CONFIG" ] && sed -i 's|@theme ".*"|@theme "gruvbox-light-soft"|' "$CONFIG"
