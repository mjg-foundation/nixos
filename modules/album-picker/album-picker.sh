#!/usr/bin/env bash

# Main loop to allow rerolling
while true; do
  # Find all albums in ~/Music (Artist/Album structure)
  mapfile -t albums < <(find ~/Music -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort)

  # Check if any albums were found
  if [ "${#albums[@]}" -eq 0 ]; then
    if command -v kdialog &>/dev/null; then
      kdialog --title "No Albums" --msgbox "No albums found in ~/Music"
    else
      echo "No albums found in ~/Music" >&2
    fi
    exit 1
  fi

  # Randomly select an album
  selected="${albums[RANDOM % ${#albums[@]}]}"

  # Find first audio file in the album directory
  audio_file=$(find "$selected" -maxdepth 1 -type f \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" \) | head -n 1)

  # Extract artist and album from tags if audio file exists
  if [ -n "$audio_file" ]; then
    artist=$(ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$audio_file")
    album=$(ffprobe -v quiet -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$audio_file")

    # Fallback to directory names if tags are empty
    if [ -z "$artist" ]; then
      artist=$(basename "$(dirname "$selected")")
    fi
    if [ -z "$album" ]; then
      album=$(basename "$selected")
    fi
  else
    # Fallback to directory names if no audio file found
    artist=$(basename "$(dirname "$selected")")
    album=$(basename "$selected")
  fi

  # Display in popup dialog with custom buttons
  if command -v kdialog &>/dev/null; then
    set +e
    kdialog --title "Album Selected" --geometry 400x250 \
      --yes-label "Play" --no-label "Reroll" --cancel-label "Cancel" \
      --yesnocancel "Artist: $artist
Album: $album

What would you like to do?"
    exit_code=$?
    set -e

    if [ "$exit_code" -eq 0 ]; then
      # User clicked Play - open cmus

      # Get all audio files and sort by disc then track number for the playlist
      # shellcheck disable=SC2016
      mapfile -t tracks < <(
        find "$selected" -maxdepth 1 -type f \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" \) -print0 |
        xargs -0 -I {} sh -c 'disc=$(ffprobe -v quiet -show_entries format_tags=disc -of default=noprint_wrappers=1:nokey=1 "{}"); track=$(ffprobe -v quiet -show_entries format_tags=track -of default=noprint_wrappers=1:nokey=1 "{}"); printf "%03d %03d %s\n" "${disc:-1}" "${track:-999}" "{}"' |
        sort -n |
        cut -d' ' -f3-
      )

      # Check if cmus is already running
      if cmus-remote -Q &>/dev/null; then
        # Cmus is running; append the album to the Default playlist.
        for track in "${tracks[@]}"; do
          cmus-remote -P "$track"
        done
      else
        # cmus not running, open in kitty
        kitty --class cmus -e cmus &
        # Wait for cmus to start
        sleep 1.5
        # Add tracks to the Default playlist in order.
        for track in "${tracks[@]}"; do
          cmus-remote -P "$track"
        done
        # Preserve a resumed playing session; otherwise start the restored track.
        if ! cmus-remote -Q | grep -qx 'status playing'; then
          cmus-remote -C player-play
        fi
      fi
    elif [ "$exit_code" -eq 1 ]; then
      # User clicked Reroll - continue loop to select another album
      continue
    else
      # User clicked Cancel or closed dialog
      exit 0
    fi
  else
    echo "Album Selected"
    echo "Artist: $artist"
    echo "Album: $album"
    exit 0
  fi

  # If we played an album, exit
  exit 0
done
