#!/bin/sh

sed -i 's/medium_light/hard_dark/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 0.9/' ~/.config/alacritty/alacritty.toml
~/.cargo/bin/nvim-ctrl 'TransparentEnable'
~/.cargo/bin/nvim-ctrl 'set background=dark'
