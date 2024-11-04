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

  # Some repositories allow the documentation build to exit early if there are no doc-related changes
  # For these repos, we fetch the latest changes from the target branch of the pull request and check
  # for changes in specified files and directories with git diff.
  case $GITHUB_PR_BASE_REPO in

    # repositories with a docs dir and changelog
    "apm-aws-lambda" | "apm-agent-android" | "apm-agent-nodejs" | "apm-agent-python" | "apm-agent-ruby" | "apm-agent-rum-js" | "apm-agent-go" | "apm-agent-java" | "apm-agent-dotnet" | "apm-agent-php" | "apm-agent-ios")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs CHANGELOG.asciidoc)
      ;;
      
    # repositories with a docs dir
    "apm-k8s-attacher" | "cloud" | "cloud-assets" | "cloud-on-k8s" | "ecctl" | "ecs" | "ecs-dotnet" | "ecs-logging" | "ecs-logging-go-logrus" | "ecs-logging-go-zap" | "ecs-logging-go-zerolog" | "ecs-logging-java" | "ecs-logging-nodejs" | "ecs-logging-php" | "ecs-logging-python" | "ecs-logging-ruby" | "elasticsearch-js" | "elasticsearch-js-legacy" | "elasticsearch-ruby" | "elasticsearch-php" | "elasticsearch-perl" | "elasticsearch-rs" | "kibana-cn" | "logstash" | "logstash-docs" | "security-docs" | "sense" | "swiftype")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs)
      ;;
      
    # repositories with a docs dir, changelogs dir, and changelog
    "apm-server")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs ./changelogs CHANGELOG.asciidoc)
      ;;

    "beats")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./auditbeat ./CHANGELOG.asciidoc ./docs ./filebeat ./heartbeat ./journalbeat ./libbeat/docs ./libbeat/outputs/*/docs/* ./libbeat/processors/*/docs/* ./metricbeat ./packetbeat ./topbeat/docs ./winlogbeat ./x-pack/auditbeat ./x-pack/dockerlogbeat/docs ./x-pack/filebeat/docs ./x-pack/filebeat/processors/*/docs/* ./x-pack/libbeat/docs ./x-pack/libbeat/processors/*/docs/* ./x-pack/metricbeat/module)
      ;;

    "clients-team")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/examples/elastic-cloud)
      ;;

    "curator")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/asciidoc)
      ;;

    "eland" | "enterprise-search-php" | "enterprise-search-python" | "enterprise-search-ruby")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/guide)
      ;;

    "elasticsearch")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./buildSrc ./build-tools-internal ./build-tools/src/main/resources ./client ./docs ./modules/reindex/src/internalClusterTest/java/org/elasticsearch/client/documentation ./modules/reindex/src/test/java/org/elasticsearch/client/documentation ./plugins/examples ./server/src/internalClusterTest/java/org/elasticsearch/client/documentation ./server/src/main/resources/org/elasticsearch/common ./server/src/test/java/org/elasticsearch/client/documentation ./x-pack/docs ./x-pack/plugin/esql/qa/testFixtures/src/main/resources ./x-pack/plugin/sql/qa ./x-pack/qa/sql)
      ;;

    "elasticsearch-hadoop")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/src/reference/asciidoc)
      ;;

    "elasticsearch-java")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs ./java-client/src/test/java/co/elastic/clients/documentation)
      ;;

    "elasticsearch-net")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs ./tests/Tests/Documentation)
      ;;

    "elasticsearch-py")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/guide ./docs/examples)
      ;;

    "go-elasticsearch")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./.doc)
      ;;

    "enterprise-search-pubs")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./enterprise-search-docs ./workplace-search-docs ./app-search-docs ./esre-docs ./client-docs/app-search-javascript ./client-docs/app-search-node ./client-docs/workplace-search-node)
      ;;

    "enterprise-search-js")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./packages/enterprise-search/docs)
      ;;

    "esf" | "ingest-docs" | "observability-docs" | "stack-docs" | "x-pack-logstash")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/en)
      ;;

    "packagespec")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./versions ./spec)
      ;;

    "tech-content")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./welcome-to-elastic)
      ;;

    "terraform-provider-ec")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs-elastic)
      ;;

    "x-pack")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/public/graph ./docs/public/marvel ./docs/public/reporting ./docs/public/shield ./docs/public/watcher ./docs/en ./docs/kr ./docs/jp)
      ;;

    "x-pack-elasticsearch")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/en ./docs/kr ./docs/jp ./qa/sql)
      ;;

    "x-pack-kibana")
      git fetch origin "$GITHUB_PR_TARGET_BRANCH"
      docs_diff=$(git diff --stat "origin/$GITHUB_PR_TARGET_BRANCH"...HEAD -- ./docs/en ./docs/kr ./docs/jp)
      ;;

    # All other repos will always build
    *)
      docs_diff="always build"
      ;;
  esac

  # If docs_diff is empty, exit early and succeed
  if [[ -z $docs_diff ]]; then
    echo "pull/${GITHUB_PR_NUMBER} in ${GITHUB_PR_BASE_REPO} has no docs changes compared to ${GITHUB_PR_TARGET_BRANCH}"
    exit 0
  fi

  # Regardless of whether we build or not, we print out the diff
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
