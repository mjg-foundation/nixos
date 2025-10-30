#!/usr/bin/env bash

# Get cmus status
if ! cmus-remote -Q &>/dev/null; then
  # cmus not running - show music icon
  echo ""
  exit 0
fi

# Get current track info
status=$(cmus-remote -Q)
artist=$(echo "$status" | grep "^tag artist " | sed 's/^tag artist //')
title=$(echo "$status" | grep "^tag title " | sed 's/^tag title //')
state=$(echo "$status" | grep "^status " | awk '{print $2}')

# Only display if playing or paused
if [ "$state" = "playing" ] || [ "$state" = "paused" ]; then
  if [ -n "$artist" ] && [ -n "$title" ]; then
    echo "$artist - $title"
  elif [ -n "$title" ]; then
    echo "$title"
  fi
fi
