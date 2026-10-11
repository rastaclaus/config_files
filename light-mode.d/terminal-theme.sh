#!/bin/sh
sed -i 's/\/themes\/gruvbox_dark.toml/\/themes\/gruvbox_light.toml/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 1.0/' ~/.config/alacritty/alacritty.toml
~/.cargo/bin/nvim-ctrl 'set background=light'

sed -i 's/^theme = "gruvbox"$/theme = "gruvbox_light"/' ~/.config/helix/config.toml
pkill -USR1 -x helix 2>/dev/null; pkill -USR1 -x hx 2>/dev/null; true
