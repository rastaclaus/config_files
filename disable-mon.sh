#!/usr/bin/env bash

start_time=$(date +%s)
end_time=$((start_time + 30))

while [[ $start_time -lt $end_time ]]; do
  sleep 2
  hyprctl dispatch dpms off "HDMI-A-1"
  start_time=$(date +%s)
done
