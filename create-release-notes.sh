#!/usr/bin/env bash

set -euo pipefail

main() {

  local cdk_image; cdk_image=$(get_image cdk)
  local mothership_image; mothership_image=$(get_image mothership)
  local ui_image; ui_image=$(get_image ui)
  local mock_host_image; mock_host_image=$(get_image mock-host)
  local admin_image; admin_image=$(get_image admin)

  local current_ref; current_ref=$(git symbolic-ref --short HEAD)

  git pull --tags -q
  local latest_deployment; latest_deployment="$(get_latest_deployment 'deployed-wiremock-cloud-live-2*')"

  git checkout "$latest_deployment" -q

  local previous_cdk_image; previous_cdk_image=$(get_image cdk)
  local previous_mothership_image; previous_mothership_image=$(get_image mothership)
  local previous_ui_image; previous_ui_image=$(get_image ui)
  local previous_mock_host_image; previous_mock_host_image=$(get_image mock-host)
  local previous_admin_image; previous_admin_image=$(get_image admin)

  git checkout "$current_ref" -q

  get_release_notes \
    "Mothership" \
    "git@github.com:mocklab/mocklab-mothership.git" \
    "${previous_mothership_image#*:}" \
    "${mothership_image#*:}"

  echo
  get_release_notes \
    "UI" \
    "git@github.com:mocklab/mocklab-ui.git" \
    "${previous_ui_image#*:}" \
    "${ui_image#*:}"

  echo
  get_release_notes \
    "Mock Host" \
    "git@github.com:mocklab/mocklab-mock-host.git" \
    "${previous_mock_host_image#*:}" \
    "${mock_host_image#*:}"

  echo
  get_release_notes \
    "CDK" \
    "git@github.com:wiremock/wiremock-cloud-infrastructure.git" \
    "${previous_cdk_image#*:}" \
    "${cdk_image#*:}" \
    main

  echo
  get_release_notes \
    "Admin" \
    "git@github.com:mocklab/mocklab-admin.git" \
    "${previous_admin_image#*:}" \
    "${admin_image#*:}"

#  echo "cdk ${previous_cdk_image#*:}..${cdk_image#*:}"
#  echo "mothership ${previous_mothership_image#*:}..${mothership_image#*:}"
#  echo "ui ${previous_ui_image#*:}..${ui_image#*:}"
#  echo "mock-host ${previous_mock_host_image#*:}..${mock_host_image#*:}"
#  echo "admin ${previous_admin_image#*:}..${admin_image#*:}"
}

get_latest_deployment() {
  local pattern=$1
  git tag -l "$pattern" --sort -refname | head -n1
}

get_image() {
  local name=$1

  jq -r '.[] | select(.name=="'"$name"'") | .imageUri' imagedefinitions.json
}

get_release_notes() {
  local name=$1
  local repo=$2
  local start=$3
  local end=$4
  local branch=${5:-master}

  if [[ "$start" != "$end" ]]; then
    echo "$name $start..$end"

    rm -rf /tmp/release_notes
    mkdir /tmp/release_notes
    cd /tmp/release_notes
    git clone --filter=blob:none --no-checkout --depth 200 --single-branch --branch "$branch" "$repo" -q .
    git log --pretty="* %s" --first-parent "$start..$end"
    rm -rf /tmp/release_notes
  fi
}

main "$@"
