#!/usr/bin/env bash

set -euo pipefail

main() {
  local product=$1
  local environment=$2
  local to_deploy=${3:-cdk}

  local stack="$product-$environment"

  local cdk_image; cdk_image=$(get_image cdk)
  # check that someone hasn't just sent us some random image to execute with our AWS creds...
  if [[ $cdk_image != 499333472133.dkr.ecr.us-east-1.amazonaws.com/* ]]; then
    echo "Not running unknown cdk image $cdk_image"
    exit 1
  fi

  local mock_host_image; mock_host_image=$(get_image mock-host)
  if [[ $to_deploy == cdk ]]; then

    local ui_image; ui_image=$(get_image ui)
    local mothership_image; mothership_image=$(get_image mothership)
    local admin_image; admin_image=$(get_image admin)

    deploy_cdk "$cdk_image" "$stack" "${ui_image#*:}" "${mothership_image#*:}" "${mock_host_image#*:}" "${admin_image#*:}"
  else
    deploy_mock_hosts "$cdk_image" "$product" "$environment" "${mock_host_image#*:}"
  fi
}

get_image() {
  local name=$1

  jq -r '.[] | select(.name=="'"$name"'") | .imageUri' imagedefinitions.json
}

deploy_cdk() {
  local cdk_image=$1
  local stack=$2
  local ui_image_tag=$3
  local mothership_image_tag=$4
  local mock_host_image_tag=$5
  local admin_image_tag=$6

  echo "Deploying ui $ui_image_tag, mothership $mothership_image_tag, admin $admin_image_tag using cdk ${cdk_image#*:}"

  docker_run \
      "$cdk_image" \
      deploy "$stack" \
      --require-approval never \
      --parameters uiImageTag="$ui_image_tag" \
      --parameters mothershipImageTag="$mothership_image_tag" \
      --parameters mockHostImageTag="$mock_host_image_tag" \
      --parameters adminImageTag="$admin_image_tag"

  tag_deployment "$stack"
}

deploy_mock_hosts() {
  local cdk_image=$1
  local product=$2
  local environment=$3
  local mock_host_image_tag=$4

  echo "Deploying mock host $mock_host_image_tag using cdk ${cdk_image#*:}"

  docker_run \
      --entrypoint deploy_mock_hosts.sh \
      "$cdk_image" \
      "$product" \
      "$environment" \
      "$mock_host_image_tag"

  local stack="$product-$environment"

  tag_deployment "$stack-mock-hosts"
}

docker_run() {
  docker run --quiet --rm \
    -e AWS_DEFAULT_REGION \
    -e AWS_REGION \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -e AWS_SESSION_TOKEN \
    "$@"
}

tag_deployment() {
  local stack=$1

  git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git config --local user.name "github-actions[bot]"
  git tag "deployed-$stack-$(date -u +%Y-%m-%dT%H-%M%SZ)"
  git push --tags
}

main "$@"
