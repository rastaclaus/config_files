#!/bin/bash

# Каталог с изображениями
WALLPAPER_DIR="$HOME/Wallpapers"

# Получаем случайное изображение из каталога
IMAGE=$(ls "$WALLPAPER_DIR" | shuf -n 1)

# Полный путь к изображению
IMAGE_PATH="$WALLPAPER_DIR/$IMAGE"

# Получаем размеры мониторов
MONITOR1=$(swaymsg -t get_outputs | jq -r '.[] | select(.active) | .name' | sed -n '1p')
MONITOR2=$(swaymsg -t get_outputs | jq -r '.[] | select(.active) | .name' | sed -n '2p')

echo $MONITOR1
echo $MONITOR2

# Разделяем изображение на две части
magick "$IMAGE_PATH" -crop 50%x100% +repage /tmp/%d_$IMAGE

ls -alh /tmp/*.jpg

# Устанавливаем обои
swaybg -o "$MONITOR1" -i "/tmp/0_$IMAGE" --mode fill &
swaybg -o "$MONITOR2" -i "/tmp/1_$IMAGE" --mode fill &
