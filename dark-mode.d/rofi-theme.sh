#!/bin/sh
# rofi theme for dark mode.
CONFIG="$HOME/.config/rofi/config.rasi"
[ -f "$CONFIG" ] && sed -i 's|@theme ".*"|@theme "gruvbox-dark-soft"|' "$CONFIG"
