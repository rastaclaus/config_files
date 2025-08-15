#!/bin/sh

sed -i 's/bamboo_light/bamboo/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 0.8/' ~/.config/alacritty/alacritty.toml
~/.cargo/bin/nvim-ctrl 'TransparentEnable'
~/.cargo/bin/nvim-ctrl 'set background=dark'
