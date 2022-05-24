#!/usr/bin/env bash

set -euo pipefail

main() {
  local stack=$1

  local cdk_image; cdk_image=$(get_cdk_image)

  do_deploy "$cdk_image" "$stack"
}

get_cdk_image() {
  jq -r '.[] | select(.name=="cdk") | .imageUri' imagedefinitions.json
}

do_deploy() {
  local cdk_image=$1
  local stack=$2

  docker run --rm \
      --mount "type=bind,src=${PWD}/imagedefinitions.json,target=/etc/imagedefinitions.json" \
      "$cdk_image" \
      list
}

main "$@"
