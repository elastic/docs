#!/bin/bash

last_successful_build_url="https://api.buildkite.com/v2/organizations/elastic/pipelines/docs-build/builds?branch=master&state=passed"
LAST_SUCCESSFUL_COMMIT=$(curl -s -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" $last_successful_build_url | jq -r '.[0].commit')

echo "Comparing the current docs build commit ${BUILDKITE_COMMIT} to the last successful build commit ${LAST_SUCCESSFUL_COMMIT}"
if [[ "$BUILDKITE_COMMIT" == "$LAST_SUCCESSFUL_COMMIT" ]]; then
  echo "The docs repo has not changed since the last build."
  buildkite-agent meta-data set "REBUILD" ""
else
  echo "The docs repo has changed since the last build."
  buildkite-agent meta-data set "REBUILD" "rebuild"
fi
