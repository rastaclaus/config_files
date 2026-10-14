#!/bin/sh
# waybar theme for dark mode. Waybar reloads the style on change.
STYLE="$HOME/.config/waybar/style.css"
[ -f "$STYLE" ] || exit 0
sed -i \
    -e 's|@define-color bar_bg .*|@define-color bar_bg #282828;|' \
    -e 's|@define-color bar_fg .*|@define-color bar_fg #ebdbb2;|' \
    -e 's|@define-color bar_accent .*|@define-color bar_accent #fabd2f;|' \
    -e 's|@define-color bar_inactive .*|@define-color bar_inactive #928374;|' \
    -e 's|@define-color bar_critical .*|@define-color bar_critical #fb4934;|' \
    "$STYLE"
