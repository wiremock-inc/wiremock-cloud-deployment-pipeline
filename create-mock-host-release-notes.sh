#!/usr/bin/env bash

set -euo pipefail

main() {

  local mock_host_image; mock_host_image=$(get_image mock-host)

  local current_ref; current_ref=$(git symbolic-ref --short HEAD)

  git fetch --tags -q
  local latest_deployment; latest_deployment="$(get_latest_deployment 'deployed-wiremock-cloud-live-mock-hosts-2*')"

  git checkout "$latest_deployment" -q

  echo "Previous Mock Host deployment was [${latest_deployment#*deployed-wiremock-cloud-live-mock-hosts-}](https://github.com/wiremock/wiremock-cloud-deployment-pipeline/commit/$(git rev-parse HEAD)/checks)"
  echo

  local previous_mock_host_image; previous_mock_host_image=$(get_image mock-host)

  git checkout "$current_ref" -q

  get_release_notes \
    "Mock Host" \
    "wiremock-inc/mock-host" \
    "${previous_mock_host_image#*:}" \
    "${mock_host_image#*:}"
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

    rm -rf /tmp/release_notes
    mkdir /tmp/release_notes
    cd /tmp/release_notes
    git clone --filter=blob:none --no-checkout --depth 200 --single-branch --branch "$branch" "git@github.com:$repo.git" -q .

    echo "[$name](https://github.com/$repo/compare/$start..$end) [$start](https://github.com/$repo/releases/tag/$start) -> [$end](https://github.com/$repo/releases/tag/$end)"
    git log --pretty="* %s" --first-parent "$start..$end" | sed -E "s|\(#([0-9]+)\)|([#\1](https://github.com/$repo/pull/\1))|"
    rm -rf /tmp/release_notes
  fi
}

main "$@"
