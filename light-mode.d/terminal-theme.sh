#!/bin/sh
sed -i 's/\/themes\/bamboo.toml/\/themes\/bamboo_light.toml/' ~/.config/alacritty/alacritty.toml
sed -i 's/opacity = .*/opacity = 1.0/' ~/.config/alacritty/alacritty.toml
sed -i 's/theme = "dark"/theme = "light"/' ~/.config/helix/config.toml
~/.cargo/bin/nvim-ctrl 'set background=light'
