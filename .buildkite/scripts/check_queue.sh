#!/bin/bash

build_data_url="https://api.buildkite.com/v2/organizations/elastic/pipelines/${BUILDKITE_PIPELINE_SLUG}/builds?branch=${BUILDKITE_BRANCH}"
cancel_build_url="https://api.buildkite.com/v2/organizations/elastic/pipelines/${BUILDKITE_PIPELINE_SLUG}/builds/${BUILDKITE_BUILD_NUMBER}/cancel"

# Don't look at this build (it's running now!)
# Don't look at the last build (it's okay if it's still running!)
# Look three builds back instead (if this build is still running,
# it means there's already one in the queue and we can safely cancel this one)
THIRD_TO_LAST_BUILD_STATE=$(curl -s -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" $build_data_url | jq -r '.[2].state')

echo "Determining if there are multiple builds waiting."
if [[ "$THIRD_TO_LAST_BUILD_STATE" == "running" ]]; then
  echo "The pipeline is congested. Canceling this build."
  curl -sX PUT -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" $cancel_build_url
else
  echo "The pipeline is ready for a new build."
fi
