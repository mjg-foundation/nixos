#!/usr/bin/env bash

set -euo pipefail

profiles=$(powerprofilesctl list | awk '
  /^[[:space:]]*(\*[[:space:]]*)?[[:lower:]-]+:$/ {
    sub(/^[[:space:]]*/, "")
    sub(/^\*[[:space:]]*/, "")
    sub(/:$/, "")
    print
  }
')

if [ -z "$profiles" ]; then
  rofi -e "No power profiles are available."
  exit 1
fi

current_profile=$(powerprofilesctl get)
selected_profile=$(printf '%s\n' "$profiles" | rofi -dmenu -i -no-custom \
  -p 'Power profile' -select "$current_profile")

[ -n "$selected_profile" ] || exit 0

powerprofilesctl set "$selected_profile"
