#!/usr/bin/env bash

set -exuo pipefail

main() {
  local monitor_name=$1
  local duration_minutes=$2
  local dd_api_key=$3
  local dd_application_key=$4

  local monitor_id; monitor_id="$(find_monitor_id "$monitor_name" "$dd_api_key" "$dd_application_key")"
  mute_monitor "$monitor_id" "$duration_minutes" "$dd_api_key" "$dd_application_key"
}

find_monitor_id() {
  local monitor_name=$1
  local dd_api_key=$2
  local dd_application_key=$3

  curl -sSf "https://api.datadoghq.com/api/v1/monitor/search" \
    -H "Accept: application/json" \
    -H "DD-API-KEY: ${dd_api_key}" \
    -H "DD-APPLICATION-KEY: ${dd_application_key}" | jq -r ".monitors[] | select(.name == \"$monitor_name\") | .id"
}

mute_monitor() {
  local monitor_id=$1
  local duration_minutes=$2
  local dd_api_key=$3
  local dd_application_key=$4

  local query; query=$(calculate_query "$duration_minutes")

  curl -sSf -X POST "https://api.datadoghq.com/api/v1/monitor/$monitor_id/mute$query" \
      -H "Accept: application/json" \
      -H "DD-API-KEY: ${dd_api_key}" \
      -H "DD-APPLICATION-KEY: ${dd_application_key}"
}

calculate_query() {
  local duration_minutes=$1

  if [[ -n "$duration_minutes" ]]; then
    local unmute_time; unmute_time=$( date -d "$duration_minutes minutes" +%s )
    echo "?end=$unmute_time"
  else
    echo ""
  fi
}

main "$@"
