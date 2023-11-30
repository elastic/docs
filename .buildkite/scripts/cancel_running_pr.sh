#!/bin/bash
set -euo pipefail
set +x

# This script should only be invoked by the Buildkite PR bot
if [ -z ${GITHUB_PR_NUMBER+set} ] || [ -z ${GITHUB_PR_BASE_REPO+set} ];then
  echo "One of the following env. variable GITHUB_PR_NUMBER, GITHUB_PR_BASE_REPO is missing - exiting."
  exit 1
fi

running_builds_url="https://api.buildkite.com/v2/organizations/elastic/pipelines/${BUILDKITE_PIPELINE_SLUG}/builds"
running_builds_url+="?branch=${BUILDKITE_PIPELINE_DEFAULT_BRANCH}&state[]=scheduled&state[]=running"
jq_filter="map(select(any(.meta_data; .repo_pr == \"${GITHUB_PR_BASE_REPO}_${GITHUB_PR_NUMBER}\"))) | .[] .number"

for bn in $(curl -sH "Authorization: Bearer ${BUILDKITE_API_TOKEN}" $running_builds_url | jq -c "${jq_filter}"); do
  if [ "$bn" != "${BUILDKITE_BUILD_NUMBER}" ];then
    echo "Cancelling build ${bn} targetting the same PR"
    cancel_url="https://api.buildkite.com/v2/organizations/elastic/pipelines/${BUILDKITE_PIPELINE_SLUG}/builds/${bn}/cancel"
    curl --silent -X PUT -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" "${cancel_url}" > /dev/null
  fi
done


