#!/bin/sh

sed -i 's/\/themes\/bamboo_light.toml/\/themes\/bamboo.toml/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 0.8/' ~/.config/alacritty/alacritty.toml
sed -i 's/theme = "light"/theme = "dark"/' ~/.config/helix/config.toml
~/.cargo/bin/nvim-ctrl 'TransparentEnable'
~/.cargo/bin/nvim-ctrl 'set background=dark'
