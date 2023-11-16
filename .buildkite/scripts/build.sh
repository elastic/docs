#!/bin/bash

set -euo pipefail
set +x

build_args=""
rebuild_opt=""
broken_links_opt=""

if [[ "${REBUILD}" == 'rebuild' ]]; then
  rebuild_opt="--rebuild"
fi

if [[ "${BROKEN_LINKS}" == 'skiplinkcheck' ]]; then
  broken_links_opt="--skiplinkcheck"
else
  if [[ "${BROKEN_LINKS}" == 'warnlinkcheck' ]]; then
    broken_links_opt="--warnlinkcheck"
  fi
fi

if [[ "${BUILDKITE_BRANCH}" == "master" ]]; then
  # temporary pushing to staging instead of master until the migration is over
  build_args+=" --target_branch staging --push"
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
