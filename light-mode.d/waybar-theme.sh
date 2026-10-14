#!/bin/sh
# waybar theme for light mode. Waybar reloads the style on change.
STYLE="$HOME/.config/waybar/style.css"
[ -f "$STYLE" ] || exit 0
sed -i \
    -e 's|@define-color bar_bg .*|@define-color bar_bg #fbf1c7;|' \
    -e 's|@define-color bar_fg .*|@define-color bar_fg #3c3836;|' \
    -e 's|@define-color bar_accent .*|@define-color bar_accent #b57614;|' \
    -e 's|@define-color bar_inactive .*|@define-color bar_inactive #928374;|' \
    -e 's|@define-color bar_critical .*|@define-color bar_critical #9d0006;|' \
    "$STYLE"
