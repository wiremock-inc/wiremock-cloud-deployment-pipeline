#!/usr/bin/env bash

set -euo pipefail

main() {
  local stack=$1

  local cdk_image; cdk_image=$(get_cdk_image)
  # check that someone hasn't just sent us some random image to execute with our AWS creds...
  if [[ $cdk_image != 499333472133.dkr.ecr.us-east-1.amazonaws.com/* ]]; then
    echo "Not running unknown cdk image $cdk_image"
    exit 1
  fi

  do_deploy "$cdk_image" "$stack"
}

get_cdk_image() {
  jq -r '.[] | select(.name=="cdk") | .imageUri' imagedefinitions.json
}

do_deploy() {
  local cdk_image=$1
  local stack=$2

  docker run --rm \
      -e AWS_DEFAULT_REGION \
      -e AWS_REGION \
      -e AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY \
      -e AWS_SESSION_TOKEN \
      --mount "type=bind,src=${PWD}/imagedefinitions.json,target=/etc/imagedefinitions.json" \
      "$cdk_image" \
      deploy "$stack"
}

main "$@"
