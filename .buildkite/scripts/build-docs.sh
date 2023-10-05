#!/bin/bash

set -euo pipefail
set +x

# Configure the git author and committer information
export GIT_AUTHOR_NAME='Buildkite CI'
export GIT_AUTHOR_EMAIL='buildkite@elasticsearch-ci.elastic.co'
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL


build_args=""
rebuild_opt=""
broken_links_opt=""

# From https://github.com/elastic/infra/blob/master/ci/jjb/elasticsearch-ci/defs/elastic-docs/pull-requests.yml#L110
# Per https://github.com/elastic/docs/issues/1821, always rebuild all
# books for PRs to the docs repo, for now.
# When https://github.com/elastic/docs/issues/1823 is fixed, this
# should be removed and the original behavior restored.

if [[ "${REBUILD}" == 'true' ]]; then
  rebuild_opt="--rebuild"
fi

if [[ "${BROKEN_LINKS}" == 'skip' ]]; then
  broken_links_opt="--skiplinkcheck"
fi

if [[ "${BROKEN_LINKS}" == 'warn' ]]; then
  broken_links_opt="--warnlinkcheck"
fi

# When running on a branch or on main
if [[ "${BUILDKITE_PULL_REQUEST}" == "false" ]]; then
  # temporary pushing to staging instead of master until the migration is over
  build_args+=" --target_branch staging"
else
  build_args+=" --target_branch docs_bk_${BUILDKITE_PULL_REQUEST}"
  build_args+=" --announce_preview https://docs_bk_${BUILDKITE_PULL_REQUEST}.docs-preview.app.elstc.co/diff"
fi

# The docs build can use the ssh agent's authentication socket
# but can't use ssh keys directly so we start an ssh-agent.

ssh-agent bash -c "
  ssh-add &&
  ./build_docs --all \
    --target_repo git@github.com:elastic/built-docs \
    $build_args \
    $rebuild_opt $broken_links_opt \
    --reference /opt/git-mirrors/ \
    --push"
