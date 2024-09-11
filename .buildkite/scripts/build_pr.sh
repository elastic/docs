#!/bin/bash
set -euo pipefail
set +x

# This script should only be invoked by the Buildkite PR bot
if [ -z ${GITHUB_PR_TARGET_BRANCH+set} ] || [ -z ${GITHUB_PR_NUMBER+set} ] || [ -z ${GITHUB_PR_BASE_REPO+set} ];then
  echo "One of the following env. variable GITHUB_PR_TARGET_BRANCH, GITHUB_PR_NUMBER, GITHUB_PR_BASE_REPO is missing - exiting."
  exit 1
fi

# Configure the git author and committer information
export GIT_AUTHOR_NAME='Buildkite CI'
export GIT_AUTHOR_EMAIL='docs-status+buildkite@elastic.co'
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

# Set some metadata for build filtering capabilities
# https://buildkite.com/elastic/docs-build-pr/builds?meta_data[repo]=tech-content
# https://buildkite.com/elastic/docs-build-pr/builds?meta_data[repo_pr]=tech-content_123
buildkite-agent meta-data set "repo" "${GITHUB_PR_BASE_REPO}"
buildkite-agent meta-data set "repo_pr" "${GITHUB_PR_BASE_REPO}_${GITHUB_PR_NUMBER}"

rebuild_opt=""
build_args=""
TARGET_BRANCH=""

# Define build docs arguments
if [[ ${GITHUB_PR_COMMENT_VAR_REBUILD_OPT:="unset"} == "rebuild" ]];then
  rebuild_opt=" --rebuild"
elif [[ ${GITHUB_PR_COMMENT_VAR_SKIP_OPT:="unset"} == "skiplinkcheck" ]];then
  build_args+=" --skiplinkcheck"
elif [[ ${GITHUB_PR_COMMENT_VAR_WARN_OPT:="unset"} == "warnlinkcheck" ]];then
  build_args+=" --warnlinkcheck"
fi

buildkite-agent \
    annotate \
    --style "info" \
    --context 'docs-info' \
    "Triggered by a doc change in elastic/$GITHUB_PR_BASE_REPO PR: [#$GITHUB_PR_NUMBER](https://github.com/elastic/$GITHUB_PR_BASE_REPO/pull/$GITHUB_PR_NUMBER)"


if [[ "${GITHUB_PR_BASE_REPO}" != 'docs' ]]; then
  # Buildkite PR bot for repositories other than the `elastic/docs` repo are configured to
  # always checkout the master branch of the `elastic/docs` repo (where the build logic resides).
  # We first need to checkout the product repo / branch in a sub directory, that we'll reference
  # in the build process.
  echo "Cloning the ${GITHUB_PR_BASE_REPO} PR locally"

  git clone --reference /opt/git-mirrors/elastic-$GITHUB_PR_BASE_REPO \
    git@github.com:elastic/$GITHUB_PR_BASE_REPO.git ./product-repo

  cd ./product-repo &&
      git fetch origin pull/$GITHUB_PR_NUMBER/head:pr_$GITHUB_PR_NUMBER &&
      git switch pr_$GITHUB_PR_NUMBER

  if [[ "${GITHUB_PR_BASE_REPO}" == 'apm-agent-go' ]]; then
    git fetch origin "$GITHUB_PR_TARGET_BRANCH"
    docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs CHANGELOG.asciidoc)
  else
    docs_diff="always build"
  fi

  if [[ -z $docs_diff ]]; then
    echo "pull/${GITHUB_PR_NUMBER} in ${GITHUB_PR_BASE_REPO} has no docs changes compared to ${GITHUB_PR_TARGET_BRANCH}"
    exit 0
  fi

  echo "diff:"
  echo "$docs_diff"

  cd ..
  # For product repos - context in https://github.com/elastic/docs/commit/5b06c2dc1f50208fcf6025eaed6d5c4e81200330
  build_args+=" --keep_hash"
  build_args+=" --sub_dir $GITHUB_PR_BASE_REPO:$GITHUB_PR_TARGET_BRANCH:./product-repo"
else
  # Buildkite PR bot for the `elastic/docs` repo is configured to checkout the PR directly into the workspace
  # We don't have to do anything else in this case.

  # Per https://github.com/elastic/docs/issues/1821, always rebuild all
  # books for PRs to the docs repo, for now.
  # When https://github.com/elastic/docs/issues/1823 is fixed, this
  # should be removed and the original behavior restored.
  rebuild_opt=" --rebuild --procs 16"
fi


# Set the target branch and preview options
TARGET_BRANCH="${GITHUB_PR_BASE_REPO}_bk_${GITHUB_PR_NUMBER}"
PREVIEW_URL="https://${TARGET_BRANCH}.docs-preview.app.elstc.co"

build_cmd="./build_docs --all \
  --target_repo git@github.com:elastic/built-docs \
  --reference /opt/git-mirrors/ \
  --target_branch ${TARGET_BRANCH} \
  --push \
  --announce_preview ${PREVIEW_URL}/diff \
  ${rebuild_opt} \
  ${build_args}"

echo "The following build command will be used"
echo $build_cmd

# Temporary workaround until we can move to HTTPS auth
vault read -field=private-key secret/ci/elastic-docs/elasticmachine-ssh-key > "$HOME/.ssh/id_rsa"
vault read -field=public-key secret/ci/elastic-docs/elasticmachine-ssh-key > "$HOME/.ssh/id_rsa.pub"
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts"
chmod 600 "$HOME/.ssh/id_rsa"

# Kick off the build
ssh-agent bash -c "ssh-add && $build_cmd"

buildkite-agent annotate \
  --style "success" \
  --context 'docs-info' \
  --append \
  "<br>Preview url: ${PREVIEW_URL}"

buildkite-agent meta-data set pr_comment:doc-preview:head " * Documentation preview
   - 📚 [HTML diff](${PREVIEW_URL}/diff)
   - 📙 [Preview](${PREVIEW_URL})"
