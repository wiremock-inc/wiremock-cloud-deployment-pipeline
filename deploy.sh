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
  local admin_image; admin_image=$(get_image admin)

  do_deploy "$cdk_image" "$stack" "${ui_image#*:}" "${mothership_image#*:}" "${mock_host_image#*:}" "${admin_image#*:}"
}

get_image() {
  local name=$1

  jq -r '.[] | select(.name=="'"$name"'") | .imageUri' imagedefinitions.json
}

do_deploy() {
  local cdk_image=$1
  local stack=$2
  local ui_image_tag=$3
  local mothership_image_tag=$4
  local mock_host_image_tag=$5
  local admin_image_tag=$6

  echo "Deploying ui $ui_image_tag, mothership $mothership_image_tag, admin $admin_image_tag using cdk ${cdk_image#*:}"

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
      --parameters uiImageTag="$ui_image_tag" \
      --parameters mothershipImageTag="$mothership_image_tag" \
      --parameters mockHostImageTag="$mock_host_image_tag" \
      --parameters adminImageTag="$admin_image_tag"
}

main "$@"
