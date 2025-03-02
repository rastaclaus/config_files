#!/bin/zsh
notify-send "Switch to $1 mode"

# GTK
gsettings set org.gnome.desktop.interface gtk-theme "$1"
gsettings set org.gnome.desktop.interface color-scheme "prefer-$1"

# Qt
export QT_STYLE_OVERRIDE=kvantum-$1
kvantummanager --set "$1"
