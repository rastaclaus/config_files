#!/bin/bash

# Проверка, запущен ли waybar
pgrep -x "waybar" > /dev/null
if [ $? -eq 0 ]; then
    echo "Waybar is running"
    # Отправляем сигнал SIGUSR1
    pkill -USR1 waybar
else
    echo "Waybar is not running"
    # Запускаем waybar
    waybar &
    sleep 1
    # После того как waybar запущен, отправляем сигнал SIGUSR1
    pkill -USR1 waybar
fi

