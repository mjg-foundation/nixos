#!/usr/bin/env bash

set -euo pipefail

config_path="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

if [ ! -r "$config_path" ]; then
  rofi -e "Could not read Hyprland's configuration:\n$config_path"
  exit 1
fi

awk '
  function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
  }

  function formatModifiers(value, parts, count, partIndex, result) {
    gsub(/\$mainMod/, "MOD", value)
    count = split(trim(value), parts, /[[:space:]]+/)
    for (partIndex = 1; partIndex <= count; partIndex++) {
      if (parts[partIndex] != "") {
        result = result == "" ? parts[partIndex] : result " + " parts[partIndex]
      }
    }
    return result
  }

  /^[[:space:]]*#[[:space:]]*keybind:[[:space:]]*/ {
    keybindDescription = $0
    sub(/^[[:space:]]*#[[:space:]]*keybind:[[:space:]]*/, "", keybindDescription)
    next
  }

  /^[[:space:]]*bind(m|el|l)?[[:space:]]*=/ {
    line = $0
    sub(/^[^=]*=[[:space:]]*/, "", line)
    fieldCount = split(line, fields, /,[[:space:]]*/)

    modifiers = formatModifiers(fields[1])
    key = trim(fields[2])
    binding = modifiers == "" ? key : modifiers " + " key
    description = keybindDescription == "" ? "No description provided" : keybindDescription
    printf "%-28s %s\n", binding, description
    keybindDescription = ""
  }
' "$config_path" |
  rofi -dmenu -i -no-custom -p 'Hyprland keybindings' \
    -theme-str 'window { location: center; anchor: center; width: 70%; } listview { lines: 20; }'
