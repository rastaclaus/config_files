#!/bin/bash

TOUCHPAD_ID="$(swaymsg -t get_inputs | grep 'identifier.*Touchpad' | cut -d'"' -f4)" #give me the touchpad identifier

STATE="$(swaymsg -rt get_inputs | grep -B1 -A20 $TOUCHPAD_ID | grep send_events | cut -d'"' -f4)"

echo state is $STATE

if [ $STATE = "enabled" ]
then
  swaymsg input "$TOUCHPAD_ID" events disabled
  notify-send Touchpad disabled
else
  swaymsg input "$TOUCHPAD_ID" events enabled
  notify-send Touchpad enabled
fi
