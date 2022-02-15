#!/bin/zsh

ps aux | grep " [w]aybar" > /dev/null 2&>1

if [ "$?" -eq 0 ]
then
  ps aux | grep " [w]aybar" | awk '{ print $2 }' | xargs kill
else
  waybar
fi
