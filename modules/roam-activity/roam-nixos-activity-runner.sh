#!/usr/bin/env bash

set -euo pipefail

if [ -z "${ROAM_ACCESS_TOKEN:-}" ]; then
  echo "ROAM_ACCESS_TOKEN is not set in the login environment" >&2
  exit 1
fi

api_base="https://api.ro.am/v1"
auth_header="Authorization: Bearer $ROAM_ACCESS_TOKEN"
user_id="${ROAM_USER_ID:-}"

if [ -z "$user_id" ]; then
  echo "ROAM_USER_ID is not set in the login environment" >&2
  exit 1
fi

payload="$(jq -cn --arg user_id "$user_id" '{
  externalId: "nixos:snowflake",
  userId: $user_id,
  display: {
    emoji: "❄️",
    title: "NixOS",
    subtitle: "Nix Snowflake",
    color: "blue"
  },
  ttlSeconds: 3600
}')"

curl --fail --silent --show-error \
  --request POST \
  --header "$auth_header" \
  --header "Content-Type: application/json" \
  --data "$payload" \
  "$api_base/user.activity.set" >/dev/null
