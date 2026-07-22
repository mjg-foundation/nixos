#!/usr/bin/env bash

set -euo pipefail

battery_device=$(upower -e | awk '/battery/ { print; exit }')
profile=$(powerprofilesctl get 2>/dev/null || printf 'unknown')

if [ -z "$battery_device" ]; then
  printf '{"text":"󰂑","tooltip":"No battery\\nProfile: %s","class":"unknown"}\n' "$profile"
  exit 0
fi

battery_info=$(upower -i "$battery_device")
percentage=$(awk -F: '/percentage:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }' <<< "$battery_info")
state=$(awk -F: '/state:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }' <<< "$battery_info")
power=$(awk -F: '/energy-rate:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }' <<< "$battery_info")
charge=${percentage%%%}
low_battery_threshold=20

if [ "$state" = "charging" ]; then
  icon="󰂄"
  class="charging"
elif [ "$state" = "fully-charged" ]; then
  icon="󰂅"
  class="plugged"
else
  icons=("󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹")
  icon_index=$((charge / 10))
  icon_index=$((icon_index > 9 ? 9 : icon_index))
  icon="${icons[icon_index]}"
  class="discharging"

  if [ "$charge" -le "$low_battery_threshold" ]; then
    class="critical"
  fi
fi

case "$state" in
  charging)
    direction="↑"
    ;;
  discharging)
    direction="↓"
    ;;
  *)
    direction=""
    ;;
esac

if [ -n "$power" ]; then
  stats="$(printf '%.2fW%s %s' "${power% W}" "$direction" "$percentage")"
else
  stats="$percentage"
fi

printf '{"text":"%s %s","tooltip":"%s\\nProfile: %s","class":"%s"}\n' \
  "$icon" "$percentage" "$stats" "$profile" "$class"
