#!/bin/sh

sed -i 's/\/themes\/gruvbox_light.toml/\/themes\/gruvbox_dark.toml/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 0.8/' ~/.config/alacritty/alacritty.toml
~/.cargo/bin/nvim-ctrl 'set background=dark'

sed -i 's/^theme = "gruvbox_light"$/theme = "gruvbox"/' ~/.config/helix/config.toml
pkill -USR1 -x helix 2>/dev/null; pkill -USR1 -x hx 2>/dev/null; true
