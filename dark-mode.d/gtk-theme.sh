#!/bin/sh
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
cp ~/.local/share/dark-mode.d/settings.ini ~/.config/gtk-3.0
cp ~/.local/share/dark-mode.d/settings.ini ~/.config/gtk-4.0
