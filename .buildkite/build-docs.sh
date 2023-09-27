#!/bin/bash

set -euo pipefail
set -x

# Configure the git author and committer information
export GIT_AUTHOR_NAME='Buildkite CI'
export GIT_AUTHOR_EMAIL='buildkite@elasticsearch-ci.elastic.co'
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL


# From https://github.com/elastic/infra/blob/master/ci/jjb/elasticsearch-ci/defs/elastic-docs/pull-requests.yml#L110
# Per https://github.com/elastic/docs/issues/1821, always rebuild all
# books for PRs to the docs repo, for now.
# When https://github.com/elastic/docs/issues/1823 is fixed, this
# should be removed and the original behavior restored.
#rebuild_opt="--rebuild"

# rebuild_opt=""
# if [[ "${ghprbCommentBody}" == *rebuild* ]]; then
#   rebuild_opt="--rebuild"
# fi

#skiplinkcheck_opt=""
#if [[ "${ghprbCommentBody}" == *skiplinkcheck* ]]; then
#  skiplinkcheck_opt="--skiplinkcheck"
#fi
#
#warnlinkcheck_opt=""
#if [[ "${ghprbCommentBody}" == *warnlinkcheck* ]]; then
#  warnlinkcheck_opt="--warnlinkcheck"
#fi
docker images

git clone \
  --reference /opt/git-mirrors/elastic-docs \
  git@github.com:elastic/docs.git .docs

ls -lart


ls -lart /opt/git-mirrors/
# The docs build can use the ssh agent's authentication socket
# but can't use ssh keys directly so we start an ssh-agent.

ghprbPullId=123

ssh-agent bash -c "
  ssh-add &&
  ./build_docs --all \
    --target_repo git@github.com:elastic/built-docs \
    --target_branch docs_bk_${ghprbPullId} \
    --announce_preview https://docs_bk_${ghprbPullId}.docs-preview.app.elstc.co/diff \
    --announce_preview https://docs_bk_${ghprbPullId}.docs-preview.app.elstc.co/diff \
    --push \
    --reference /opt/git-mirrors/"
#    $rebuild_opt $skiplinkcheck_opt $warnlinkcheck_opt"
