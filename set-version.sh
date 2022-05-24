#!/usr/bin/env bash

set -euo pipefail

main() {
  local name=$1
  local image_uri=$2
  local source_action=$3
  local source_commit=$4

  alter_imagedefinitions "$name" imageUri "$image_uri"
  alter_imagedefinitions "$name" metadata.sourceAction "$source_action"
  alter_imagedefinitions "$name" metadata.sourceCommit "$source_commit"

  git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git config --local user.name "github-actions[bot]"

  git add imagedefinitions.json
  git commit -m "Set $name to $image_uri"
  git push
}

alter_imagedefinitions() {
  local name=$1
  local key=$2
  local value=$3

  local work_file; work_file=$(mktemp "/tmp/imagedefinitions.json.XXXXXX")
  jq '( .[] | select(.name == "'"$name"'") ).'"$key"' = "'"$value"'"' imagedefinitions.json > "$work_file"
  mv "$work_file" imagedefinitions.json
}

main "$@"
