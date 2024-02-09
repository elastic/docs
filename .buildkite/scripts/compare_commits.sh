#!/bin/bash

# curl -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" https://api.buildkite.com/v2/organizations/elastic/pipelines/docs-build/builds?branch=master&state=passed > output.json

# LAST_SUCCESSFUL_COMMIT=$(cat output.json | jq '.[0]')

LAST_SUCCESSFUL_COMMIT=$(curl -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" https://api.buildkite.com/v2/organizations/elastic/pipelines/docs-build/builds?branch=master&state=passed | jq '.[0].commit')

echo "Build commit: ${BUILDKITE_COMMIT}"
echo "Last successful commit: $LAST_SUCCESSFUL_COMMIT"

if [[ "${BUILDKITE_COMMIT}" != "$LAST_SUCCESSFUL_COMMIT" ]]; then
  echo "The docs repo has changed since the last build."
  echo buildkite-agent meta-data set "REBUILD" "rebuild"
else
  echo "The docs repo has not changed since the last build."
  echo buildkite-agent meta-data set "REBUILD" ""
fi