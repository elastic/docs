#!/bin/bash

set -euo pipefail
set +x

# Configure the git author and committer information
export GIT_AUTHOR_NAME='Buildkite CI'
export GIT_AUTHOR_EMAIL='docs-status+buildkite@elastic.co'
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

build_args=""
rebuild_opt=""
broken_links_opt=""

if [[ "${REBUILD}" == 'rebuild' ]]; then
  rebuild_opt="--rebuild"
fi

if [[ "${BROKEN_LINKS}" == 'skiplinkcheck' ]]; then
  broken_links_opt="--skiplinkcheck"
elif [[ "${BROKEN_LINKS}" == 'warnlinkcheck' ]]; then
  broken_links_opt="--warnlinkcheck"
fi

if [[ "${BUILDKITE_BRANCH}" == "master" ]]; then
  build_args+=" --push"
fi

# The docs build can use the ssh agent's authentication socket
# but can't use ssh keys directly so we start an ssh-agent.

# Temporary workaround until we can move to HTTPS auth
vault read -field=private-key secret/ci/elastic-docs/elasticmachine-ssh-key > "$HOME/.ssh/id_rsa"
vault read -field=public-key secret/ci/elastic-docs/elasticmachine-ssh-key > "$HOME/.ssh/id_rsa.pub"
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts"
chmod 600 "$HOME/.ssh/id_rsa"

ssh-agent bash -c "
  ssh-add &&
  export GEM_PATH=/var/lib/gems${GEM_PATH:+:$GEM_PATH} &&
  ./build_docs --all \
    --target_repo git@github.com:elastic/built-docs \
    --reference /opt/git-mirrors/ \
    $build_args \
    $rebuild_opt $broken_links_opt"
