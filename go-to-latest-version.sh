#!/usr/bin/env bash

set -euo pipefail

main() {
  local name=$1
  local previous_tag=$2
  local latest_tag=$3
  local source_action=$4
  local source_commit=$5

  local current_tag; current_tag="$(find_current_tag "$name")"
  echo "Current tag: $current_tag"

  local force
  if [[ "$current_tag" == "$previous_tag" ]]; then
    echo "Setting the version"
    force=true
  else
    echo "Not setting the version"
    force=false
  fi

  ./set-version.sh "$name" "$latest_tag" "$source_action" "$source_commit" "$force"
}

find_current_tag() {
  local name=$1

  local currentImageName; currentImageName=$(jq -r '( .[] | select(.name == "'"$name"'") ).imageUri' imagedefinitions.json)
  echo "${currentImageName##*:}"
}

main "$@"
