#!/bin/bash

set -euo pipefail
set -x

# Configure the git author and committer information
export GIT_AUTHOR_NAME='Buildkite CI'
export GIT_AUTHOR_EMAIL='buildkite@elasticsearch-ci.elastic.co'
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL


build_args=""
rebuild_opt=""
skiplinkcheck_opt=""
warnlinkcheck_opt=""
# From https://github.com/elastic/infra/blob/master/ci/jjb/elasticsearch-ci/defs/elastic-docs/pull-requests.yml#L110
# Per https://github.com/elastic/docs/issues/1821, always rebuild all
# books for PRs to the docs repo, for now.
# When https://github.com/elastic/docs/issues/1823 is fixed, this
# should be removed and the original behavior restored.
#rebuild_opt="--rebuild"

if [[ "${REBUILD}" == 'true' ]]; then
  rebuild_opt="--rebuild"
fi

if [[ "${SKIP_LINK_CHECK}" == 'true' ]]; then
  skiplinkcheck_opt="--skiplinkcheck"
fi

if [[ "${ALLOW_BROKEN_LINKS}" == 'true' ]]; then
  warnlinkcheck_opt="--warnlinkcheck"
fi

#git clone \
#  --reference /opt/git-mirrors/elastic-docs \
#  git@github.com:elastic/docs.git .docs


# When running on a branch or on main
if [[ "${GIT_PULL_REQUEST_ID}" != "false" ]]; then
  # temporary pushing to a branch different than main until ready to switchover
  build_args+= " --target_branch docs_bk_rollout"
else
  build_args+= " --target_branch docs_bk_${GIT_PULL_REQUEST_ID}"
  build_args+= " --announce_preview https://docs_bk_${GIT_PULL_REQUEST_ID}.docs-preview.app.elstc.co/diff"
  rebuild_opt= " --rebuild"
fi

# The docs build can use the ssh agent's authentication socket
# but can't use ssh keys directly so we start an ssh-agent.
ssh-agent bash -c "
  ssh-add &&
  ./build_docs --all \
    --target_repo git@github.com:elastic/built-docs \
    $build_args \
    $rebuild_opt $skiplinkcheck_opt $warnlinkcheck_opt \
    --reference /opt/git-mirrors/"
# --push
