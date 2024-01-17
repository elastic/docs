#!/usr/bin/env bash

set -euo pipefail
set -x
# This hook should only be invoked for builds triggered by the Buildkite PR bot
if [ -z ${GITHUB_PR_BASE_OWNER+set} ] || [ -z ${GITHUB_PR_BASE_REPO+set} ] || [ -z ${GITHUB_PR_TRIGGERED_SHA+set} ];then
  exit 0
fi

status_state=$1
description=''

case $status_state in
    pending)
      description='Build started';;
    success|failure|error)
      description='Build finished';;
    *)
      echo "Invalid state $status_state"
      exit 1;;
esac

githubPublishStatus="https://api.github.com/repos/${GITHUB_PR_BASE_OWNER}/${GITHUB_PR_BASE_REPO}/statuses/${GITHUB_PR_TRIGGERED_SHA}"
data='{"state":"'$status_state'","target_url":"'$BUILDKITE_BUILD_URL'","description":"'$description'","context":"buildkite/'$BUILDKITE_PIPELINE_SLUG'"}'

echo "Setting commit status: buildkite/${BUILDKITE_PIPELINE_SLUG} - ${status_state}"
echo +x
curl -s -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${VAULT_GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${githubPublishStatus}" \
  -d "${data}"
