#!/bin/bash

last_build_url="https://api.buildkite.com/v2/organizations/elastic/pipelines/${BUILDKITE_PIPELINE_SLUG}/builds?branch=${BUILDKITE_BRANCH}"
cancel_build_url="https://api.buildkite.com/v2/organizations/elastic/pipelines/${BUILDKITE_PIPELINE_SLUG}/builds/${BUILDKITE_JOB_ID}/cancel"

LAST_BUILD_STATE=$(curl -s -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" $last_successful_build_url | jq -r '.[1].status')

echo "Determining if the last build is currently blocked."
if [[ "$LAST_BUILD_STATE" == "blocked" ]]; then
  echo "The pipeline is congested. Canceling this build."
  curl -sX PUT -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" $cancel_build_url
else
  echo "The pipeline is ready for a new build."
fi
