#!/bin/sh

sed -i 's/\/themes\/gruvbox_light.toml/\/themes\/gruvbox_dark.toml/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 0.8/' ~/.config/alacritty/alacritty.toml
~/.cargo/bin/nvim-ctrl 'set background=dark'
