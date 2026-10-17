#!/bin/sh
# ironbar theme for light mode.
#
# Ironbar hot-reloads the stylesheet, but its file watcher does NOT survive a
# rename-based rewrite (`sed -i` replaces the file via rename, giving it a new
# inode). So we edit into a temp file and copy the bytes back over the same
# inode, which keeps the watcher intact.
STYLE="$HOME/.config/ironbar/style.css"
[ -f "$STYLE" ] || exit 0
TMP="$(mktemp)"
sed \
    -e 's|@define-color bar_bg .*|@define-color bar_bg #fbf1c7;|' \
    -e 's|@define-color bar_fg .*|@define-color bar_fg #3c3836;|' \
    -e 's|@define-color bar_accent .*|@define-color bar_accent #b57614;|' \
    -e 's|@define-color bar_inactive .*|@define-color bar_inactive #928374;|' \
    -e 's|@define-color bar_critical .*|@define-color bar_critical #9d0006;|' \
    "$STYLE" > "$TMP"
cat "$TMP" > "$STYLE"
rm -f "$TMP"
