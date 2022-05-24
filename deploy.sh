#!/usr/bin/env bash

set -euo pipefail

main() {
  local stack=$1

  local cdk_image; cdk_image=$(get_image cdk)
  # check that someone hasn't just sent us some random image to execute with our AWS creds...
  if [[ $cdk_image != 499333472133.dkr.ecr.us-east-1.amazonaws.com/* ]]; then
    echo "Not running unknown cdk image $cdk_image"
    exit 1
  fi

  local ui_image; ui_image=$(get_image ui)
  local mothership_image; mothership_image=$(get_image mothership)
  local mock_host_image; mock_host_image=$(get_image mock-host)

  do_deploy "$cdk_image" "$stack" "$ui_image" "$mothership_image" "$mock_host_image"
}

get_image() {
  local name=$1

  jq -r '.[] | select(.name=="'"$name"'") | .imageUri' imagedefinitions.json
}

do_deploy() {
  local cdk_image=$1
  local stack=$2
  local ui_image=$3
  local mothership_image=$4
  local mock_host_image=$5

  docker run --rm \
      -e AWS_DEFAULT_REGION \
      -e AWS_REGION \
      -e AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY \
      -e AWS_SESSION_TOKEN \
      --mount "type=bind,src=${PWD}/imagedefinitions.json,target=/etc/imagedefinitions.json" \
      "$cdk_image" \
      deploy "$stack" \
      --require-approval never \
      --parameters uiImage="$ui_image" \
      --parameters mothershipImage="$mothership_image" \
      --parameters mockHostImage="$mock_host_image"
}

main "$@"
