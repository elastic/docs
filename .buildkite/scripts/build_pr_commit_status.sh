#!/usr/bin/env bash

set -euo pipefail

# This hook should only be invoked for builds triggered by the Buildkite PR bot
if [ -z ${GITHUB_PR_OWNER+set} ] || [ -z ${GITHUB_PR_REPO+set} ] || [ -z ${GITHUB_PR_TRIGGERED_SHA+set} ];then
  exit 0
fi


if [ $# -lt 2 ]; then
  echo "Usage: $0 <state> <description>"
  exit 1
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

githubPublishStatus="https://api.github.com/repos/${GITHUB_PR_OWNER}/${GITHUB_PR_REPO}/statuses/${GITHUB_PR_TRIGGERED_SHA}"
data='{"state":"'$status_state'","target_url":"'$BUILDKITE_BUILD_URL'","description":"'$description'","context":"buildkite/'$BUILDKITE_PIPELINE_SLUG'"}'

echo "Setting buildkite/docs commit status to ${status_state}"
curl -s -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${githubPublishStatus}" \
  -d "${data}"
