#!/bin/sh

gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
cp ~/.local/share/light-mode.d/settings.ini ~/.config/gtk-3.0
cp ~/.local/share/light-mode.d/settings.ini ~/.config/gtk-4.0
