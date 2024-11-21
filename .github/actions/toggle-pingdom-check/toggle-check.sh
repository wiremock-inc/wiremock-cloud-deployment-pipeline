#!/usr/bin/env bash

set -exuo pipefail

main() {
  local check_name=$1
  local pause=$2
  local pingdom_token=$3

  local check_id; check_id="$(find_check_id "$check_name" "$pingdom_token")"
  toggle_check "$check_id" "$pause" "$pingdom_token"
}

find_check_id() {
  local check_name=$1
  local pingdom_token=$2

  curl -sSf "https://api.pingdom.com/api/3.1/checks" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${pingdom_token}" \
    | jq -r ".checks[] | select(.name == \"$check_name\") | .id"
}

toggle_check() {
  local check_id=$1
  local paused=$2
  local pingdom_token=$3

  curl -sSf -X PUT "https://api.pingdom.com/api/3.1/checks" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${pingdom_token}" \
      -d "{ \"checkids\": \"$check_id\", \"paused\": $paused }"
}

main "$@"
