#!/bin/bash
set -eo pipefail

set +x
GITHUB_TOKEN=$(vault read -field=value secret/ci/elastic-docs/docs_preview_cleaner)
export GITHUB_TOKEN
set -x

# TODO: Remove this temporary workaround
# Overwrite known_hosts file with the latest GitHub SSH key
ssh-keyscan -t rsa github.com > ~/.ssh/known_hosts