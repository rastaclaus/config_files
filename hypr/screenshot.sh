#!/bin/bash

# Список режимов
modes=("Window" "Region" "Monitor")

# Используем wofi для выбора режима
chosen_mode=$(printf "%s\n" "${modes[@]}" | wofi --dmenu --prompt="Select screenshot mode:")

# Проверяем, что пользователь выбрал один из режимов
if [ -z "$chosen_mode" ]; then
  echo "No mode selected, exiting."
  exit 1
fi

# Выполняем скриншот в зависимости от выбранного режима
case "$chosen_mode" in
  "Window")
    hyprshot -m window
    ;;
  "Region")
    hyprshot -m region
    ;;
  "Monitor")
    hyprshot -m output
    ;;
  *)
    echo "Invalid mode selected, exiting."
    exit 1
    ;;
esac
