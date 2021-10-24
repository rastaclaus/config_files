#!/bin/sh
FIRST=VGA-0
SECOND=HDMI-0

res=$(xrandr | grep Screen | awk -F', ' '{ print $2}' | awk '{print $2}')

if [ "$res" -eq 3840 ]
then
  notify-send "disable second monitor"
  xrandr --output $SECOND --off
else
  notify-send "enable second monitor"
  xrandr --output $SECOND --mode 1920x1080 --right-of $FIRST
fi
