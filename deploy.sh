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

  echo "ENV_SPECIFIC_SECRET = [$ENV_SPECIFIC_SECRET]"
  echo docker run --rm \
      --mount type=bind,src=imagedefinitions.json,target=/etc/imagedefinitions.json \
      "$cdk_image" \
      "$stack"
}

main "$@"
