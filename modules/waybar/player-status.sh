#!/usr/bin/env bash

# Prefer a player that is actually playing, so a stopped browser tab cannot
# take precedence over Cmus. Fall back to a paused player when nothing plays.
mapfile -t players < <(playerctl -l 2>/dev/null)
selected_player=""
paused_player=""

for player in "${players[@]}"; do
  state=$(playerctl --player="$player" status 2>/dev/null) || continue

  if [ "$state" = "Playing" ]; then
    selected_player="$player"
    break
  fi

  if [ "$state" = "Paused" ] && [ -z "$paused_player" ]; then
    paused_player="$player"
  fi
done

selected_player=${selected_player:-$paused_player}

if [ -z "$selected_player" ]; then
  echo ""
  exit 0
fi

artist=$(playerctl --player="$selected_player" metadata artist 2>/dev/null | head -n 1)
title=$(playerctl --player="$selected_player" metadata title 2>/dev/null | head -n 1)

if [ -n "$artist" ] && [ -n "$title" ]; then
  echo "$artist - $title"
elif [ -n "$title" ]; then
  echo "$title"
else
  echo ""
fi
