#!/usr/bin/env bash

set -euo pipefail

main() {
  local name=$1
  local tag_name=$2

  local current_tag; current_tag="$(find_current_tag "$name")"

  if [[ "$tag_name" == "$current_tag" ]]; then
    echo "Force redeploying $name in dev"
    if [[ "$name" == mothership ]] || [[ "$name" == ui ]] || [[ "$name" == admin ]] || [[ "$name" == superset ]]; then
      update_service "$name"
    else
      for service in $(aws ecs list-services --cluster wiremock-cloud-dev --no-paginate | jq -r '.serviceArns[]'); do
        if [[ "$service" != */mothership ]] && [[ "$service" != */ui ]] && [[ "$service" != */admin ]] && [[ "$service" != */superset ]]; then
          update_service "$service"
        fi
      done
    fi
  else
    echo "Not redeploying $name in dev, currently on $current_tag and this was triggered with $tag_name"
  fi
}

find_current_image() {
  local name=$1

  jq -r '( .[] | select(.name == "'"$name"'") ).imageUri' imagedefinitions.json
}

find_current_tag() {
  local name=$1

  local currentImageName; currentImageName=$(find_current_image "$name")
  echo "${currentImageName##*:}"
}

update_service() {
  local service=$1

  aws ecs wait services-stable \
    --cluster wiremock-cloud-dev \
    --service "$service"

  aws ecs update-service \
    --force-new-deployment \
    --cluster wiremock-cloud-dev \
    --service "$service"
}

main "$@"
