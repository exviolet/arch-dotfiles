#!/bin/bash

track=$(playerctl -p spotify metadata --format "{{ artist }} - {{ title }}")

if [ -z "$track" ]; then
  echo ""
else
  echo "$track"
fi
