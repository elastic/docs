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

ssh-agent bash -c "
  ssh-add &&
  ./build_docs --all \
    --target_repo git@github.com:elastic/built-docs \
    --reference /opt/git-mirrors/ \
    $build_args \
    $rebuild_opt $broken_links_opt"
