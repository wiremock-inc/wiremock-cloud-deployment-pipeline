#!/usr/bin/env bash

set -euo pipefail

main() {

  >&2 echo "Generating release notes"

  local cdk_image; cdk_image=$(get_image cdk)
  local mothership_image; mothership_image=$(get_image mothership)
  local ui_image; ui_image=$(get_image ui)
  local admin_image; admin_image=$(get_image admin)

  local current_ref; current_ref=$(git symbolic-ref --short HEAD)

  git fetch --tags -q

  >&2 echo 'output of git status :'
  >&2 git status
  >&2 echo 'output of git git tag -l "deployed-wiremock-cloud-live-2*" --sort -refname :'
  >&2 git tag -l 'deployed-wiremock-cloud-live-2*' --sort -refname
  local latest_deployment; latest_deployment="$(get_latest_deployment 'deployed-wiremock-cloud-live-2*')"

  >&2 echo "Checking out latest deployment $latest_deployment"
  git checkout "$latest_deployment" -q

  echo "Previous deployment was [${latest_deployment#*deployed-wiremock-cloud-live-}](https://github.com/wiremock-inc/wiremock-cloud-deployment-pipeline/commit/$(git rev-parse HEAD)/checks)"
  echo

  local previous_cdk_image; previous_cdk_image=$(get_image cdk)
  local previous_mothership_image; previous_mothership_image=$(get_image mothership)
  local previous_ui_image; previous_ui_image=$(get_image ui)
  local previous_admin_image; previous_admin_image=$(get_image admin)

  >&2 echo "Checking out current ref $current_ref"
  git checkout "$current_ref" -q

  get_release_notes \
    "Mothership" \
    "wiremock-inc/mothership" \
    "${previous_mothership_image#*:}" \
    "${mothership_image#*:}"

  echo
  get_release_notes \
    "UI" \
    "wiremock-inc/ui" \
    "${previous_ui_image#*:}" \
    "${ui_image#*:}"

  echo
  get_release_notes \
    "CDK" \
    "wiremock-inc/wiremock-cloud-infrastructure" \
    "${previous_cdk_image#*:}" \
    "${cdk_image#*:}" \
    main

  echo
  get_release_notes \
    "Admin" \
    "wiremock-inc/admin" \
    "${previous_admin_image#*:}" \
    "${admin_image#*:}"
}

git() {
  if ! command git "$@"; then
    >&2 echo "Failed running git $*"
    exit 1
  fi
}

get_latest_deployment() {
  local pattern=$1
  git tag -l "$pattern" --sort -refname | head -n1
}

get_image() {
  local name=$1

  >&2 echo "Getting image for $name"

  jq -r '.[] | select(.name=="'"$name"'") | .imageUri' imagedefinitions.json
}

get_release_notes() {
  local name=$1
  local repo=$2
  local start=$3
  local end=$4
  local branch=${5:-master}

  if [[ "$start" != "$end" ]]; then

    >&2 echo "Building release notes for $name in $repo on branch $branch because $start != $end"

    rm -rf /tmp/release_notes
    mkdir /tmp/release_notes
    cd /tmp/release_notes
    >&2 echo "Cloning git@github.com:$repo.git"
    git clone --filter=blob:none --no-checkout --depth 200 --single-branch --branch "$branch" "git@github.com:$repo.git" -q .

    echo "[$name](https://github.com/$repo/compare/$start..$end) [$start](https://github.com/$repo/releases/tag/$start) -> [$end](https://github.com/$repo/releases/tag/$end)"
    git log --pretty="* %s" --first-parent "$start..$end" | sed -E "s|\(#([0-9]+)\)|([#\1](https://github.com/$repo/pull/\1))|"
    rm -rf /tmp/release_notes
  else
    >&2 echo "Skipping building release notes for $name in $repo on branch $branch because $start == $end"
  fi
}

main "$@"
