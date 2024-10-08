#!/usr/bin/env bash

set -euo pipefail

usage="Usage: $(basename "$0") [-h] [-p product] [-e env] [-r region] [-s subdomain] services_to_deploy -- deploy our services using the CDK.

where:
    -h  show this help text
    -p  product                                 required (e.g. wiremock-cloud)
    -e  environment                             required (e.g. live, qa, dev)
    -r  region                                  required (e.g. us-east-1)
    -s  subdomain                               required if and only if services_to_deploy is cdk (e.g. dev, qa, '')
    services_to_deploy; cdk, mock-hosts         mock-hosts to deploy all mock-hosts, cdk to deploy everything else

examples:
./$(basename "$0") -p wiremock-cloud -e live -r us-east-1 -s '' cdk
./$(basename "$0") -p wiremock-cloud -e backup -r us-east-2 mock-hosts
"

while getopts ":hp:e:r:s:" opt; do
  case $opt in
    h) echo "$usage"
       exit
       ;;
    p) product="$OPTARG"
    ;;
    e) environment="$OPTARG"
    ;;
    r) region="$OPTARG"
    ;;
    s) subdomain="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    echo
    echo "$usage"
    exit 1
    ;;
  esac

  case $OPTARG in
    -*) echo "Option $opt needs a valid argument"
    echo
    echo "$usage"
    exit 1
    ;;
  esac
done

shift "$(( OPTIND - 1 ))"

WMC_ENV=$environment

main() {
  services_to_deploy=$1

  if [ -z ${product+x} ] && [ -z ${env+x} ] && [ -z ${region+x} ]; then
    echo "Missing required options"
    echo
    echo "$usage"
    exit 1
  fi

  if [ $services_to_deploy = 'cdk' ] && [ -z ${subdomain+x} ]; then
    echo "Subdomain option (-s) must be supplied when services_to_deploy is cdk"
    echo
    echo "$usage"
    exit 1
  fi


  local cdk_image; cdk_image=$(get_image cdk)
  # check that someone hasn't just sent us some random image to execute with our AWS creds...
  if [[ $cdk_image != 499333472133.dkr.ecr.us-east-1.amazonaws.com/* ]]; then
    echo "Not running unknown cdk image $cdk_image"
    exit 1
  fi
  cdk_image=${cdk_image/us-east-1/"$region"}

  local mock_host_image; mock_host_image=$(get_image mock-host)
  if [[ $services_to_deploy == cdk ]]; then

    local ui_image; ui_image=$(get_image ui)
    local mothership_image; mothership_image=$(get_image mothership)
    local admin_image; admin_image=$(get_image admin)

    local main_stack="$product-$environment"
    local mock_host_service_catalog_stack="$product-$environment-mock-host-service-catalog"
    deploy_cdk "$cdk_image" "$main_stack" "$mock_host_service_catalog_stack" "${ui_image#*:}" "${mothership_image#*:}" "${mock_host_image#*:}" "${admin_image#*:}" "$subdomain"
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
  local main_stack=$2
  local mock_host_service_catalog_stack=$3
  local ui_image_tag=$4
  local mothership_image_tag=$5
  local mock_host_image_tag=$6
  local admin_image_tag=$7
  local subdomain=$8

  echo "Deploying ui $ui_image_tag, mothership $mothership_image_tag, admin $admin_image_tag using cdk ${cdk_image#*:}"

  docker_run \
      --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
      "$cdk_image" \
      deploy "$main_stack" "$mock_host_service_catalog_stack" \
      --require-approval never \
      --parameters $main_stack:uiImageTag="$ui_image_tag" \
      --parameters $main_stack:mothershipImageTag="$mothership_image_tag" \
      --parameters $main_stack:mockHostImageTag="$mock_host_image_tag" \
      --parameters $main_stack:adminImageTag="$admin_image_tag" \
      --parameters $main_stack:subdomain="$subdomain"

  tag_deployment "$main_stack"
  tag_deployment "$mock_host_service_catalog_stack"
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
    -e WMC_ENV \
    "$@"
}

tag_deployment() {
  local stack=$1

  git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git config --local user.name "github-actions[bot]"
  git tag "deployed-$stack-$(date -u +%Y-%m-%dT%H-%M-%SZ)"
  git push --tags
}

main "$@"
