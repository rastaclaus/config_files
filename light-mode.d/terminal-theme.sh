#!/bin/sh
sed -i 's/\/themes\/gruvbox_dark.toml/\/themes\/gruvbox_light.toml/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 1.0/' ~/.config/alacritty/alacritty.toml
~/.cargo/bin/nvim-ctrl 'set background=light'
