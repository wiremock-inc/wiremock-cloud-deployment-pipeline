#!/usr/bin/env bash

set -euo pipefail

integer="(0|[1-9][0-9]*)"
qualifier="[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*"
semver_regex="^$integer\.$integer\.$integer(\-$qualifier)?(\+$qualifier)?$"

main() {
  local name=$1
  local image_uri=$2
  local source_action=${3:-set manually}
  local source_commit=${4:-set manually}
  local force=${5:-false}

  local current_tag; current_tag="$(find_current_tag "$name")"
  echo "Current tag: $current_tag force: $force"

  local update
  if "$force" || [[ "$current_tag" =~ $semver_regex ]]; then
    echo "Setting the version"
    update=true
  else
    echo "Not setting the version"
    update=false
  fi

  if $update; then

    alter_image_tag "$name" "$image_uri"
    alter_imagedefinitions "$name" metadata.sourceAction "$source_action"
    alter_imagedefinitions "$name" metadata.sourceCommit "$source_commit"

    git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git config --local user.name "github-actions[bot]"

    git add imagedefinitions.json
    git diff-index --quiet HEAD || git commit -m "Set $name to ${image_uri##*:}" -m "$image_uri"
    git push
  fi
}

alter_image_tag() {
  local name=$1
  local image_uri=$2

  if [[ "$image_uri" != *:* ]]; then
    local current_image; current_image=$(find_current_image "$name")
    image_uri="${current_image%:*}:$image_uri"
  fi

  echo "Setting $name to $image_uri"

  alter_imagedefinitions "$name" imageUri "$image_uri"
}

alter_imagedefinitions() {
  local name=$1
  local key=$2
  local value=$3

  local work_file; work_file=$(mktemp "/tmp/imagedefinitions.json.XXXXXX")
  jq '( .[] | select(.name == "'"$name"'") ).'"$key"' = "'"$value"'"' imagedefinitions.json > "$work_file"
  mv "$work_file" imagedefinitions.json
}

find_current_image() {
  local name=$1

  jq -r '( .[] | select(.name == "'"$name"'") ).imageUri' imagedefinitions.json
}

find_current_tag() {
  local name=$1

  local currentImageName; currentImageName=$(find_current_image "$name")
  echo "${currentImageName##*:}"
}

main "$@"
