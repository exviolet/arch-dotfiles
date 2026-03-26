#!/usr/bin/env bash

cliphist list | rofi -dmenu -theme ~/.config/rofi/menus/clipboard.rasi -p "Clipboard" | cliphist decode | wl-copy
