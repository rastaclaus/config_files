#!/bin/sh
sed -i 's/bamboo/bamboo_light/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 1.0/' ~/.config/alacritty/alacritty.toml
~/.cargo/bin/nvim-ctrl 'TransparentDisable'
~/.cargo/bin/nvim-ctrl 'set background=light'
