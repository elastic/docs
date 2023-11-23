#!/usr/bin/env bash

set -euo pipefail

# This hook should only be invoked for builds triggered by the Buildkite PR bot
if [ -z ${GITHUB_PR_OWNER+set} ] || [ -z ${GITHUB_PR_REPO+set} ] || [ -z ${GITHUB_PR_TRIGGERED_SHA+set} ];then
  exit 0
fi

gitHubToken=$(vault read -field=value secret/ci/elastic-docs/docs_preview_cleaner)

if [ $(buildkite-agent step get "outcome" --step "build-pr") == "passed" ]; then
  status_state="success"
else
  status_state="failure"
fi

githubPublishStatus="https://api.github.com/repos/${GITHUB_PR_OWNER}/${GITHUB_PR_REPO}/statuses/${GITHUB_PR_TRIGGERED_SHA}"
data='{"state":"'$status_state'","target_url":"'$BUILDKITE_BUILD_URL'","description":"Build finished.","context":"buildkite/'$BUILDKITE_PIPELINE_SLUG'"}'
echo "Setting buildkite/docs commit status to ${status_state}"
curl -s -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${gitHubToken}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${githubPublishStatus}" \
  -d "${data}"
