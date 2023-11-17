#!/usr/bin/env bash

set -euo pipefail

echo "The value is $MY_SECRET"

state=$(buildkite-agent step get "state" --step "build-pr-setup")
echo "State of build-pr-setup is $state"

state=$(buildkite-agent step get "outcome" --step "build-pr-setup")
echo "outcome of build-pr-setup is $state"

state=$(buildkite-agent step get "state" --step "build-pr")
echo "State is $state"

state=$(buildkite-agent step get "outcome" --step "build-pr")
echo "outcome of build-pr is $state"
# Configure the git author and committer information
export GIT_AUTHOR_NAME='Buildkite CI'
export GIT_AUTHOR_EMAIL='buildkite@elastic.co'
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

# The reminder of this hook should only be invoked for builds triggered by the Buildkite PR bot
if [ -z ${GITHUB_PR_OWNER+set} ] || [ -z ${GITHUB_PR_REPO+set} ] || [ -z ${GITHUB_PR_TRIGGERED_SHA+set} ];then
  exit 0
fi

gitHubToken=$(vault read -field=value secret/ci/elastic-docs/docs_preview_cleaner)

githubPublishStatus="https://api.github.com/repos/${GITHUB_PR_OWNER}/${GITHUB_PR_REPO}/statuses/${GITHUB_PR_TRIGGERED_SHA}"
data='{"state":"pending","target_url":"'$BUILDKITE_BUILD_URL'","description":"Build started.","context":"buildkite/'$BUILDKITE_PIPELINE_SLUG'"}'
echo "Setting buildkite/docs commit status to pending"
curl -s -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${gitHubToken}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${githubPublishStatus}" \
  -d "${data}"
