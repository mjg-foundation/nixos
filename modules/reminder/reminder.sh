#!/usr/bin/env bash

# Display popup notification
if command -v kdialog &>/dev/null; then
  kdialog --title "Reminder" --msgbox "Command finished"
else
  echo "Command finished" >&2
fi
