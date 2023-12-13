#!/bin/bash

BUILDKITE_BRANCH=$1
JENKINS_BRANCH=$2

if [ -z ${BUILDKITE_BRANCH} ] || [ -z ${JENKINS_BRANCH} ];then
    echo "Missing BUILDKITE_BRANCH or JENKINS_BRANCH - aborting"
    exit 1
fi

buildkite-agent annotate \
    --style 'info' \
    --context 'branch-comparison' \
    "Attempting to perform programatic comparison of [$BUILDKITE_BRANCH..$JENKINS_BRANCH](https://github.com/elastic/built-docs/compare/$BUILDKITE_BRANCH..$JENKINS_BRANCH)"

# Start by fetching the 2 branches
git clone --reference /opt/git-mirrors/elastic-built-docs git@github.com:elastic/built-docs.git built-docs

cd built-docs

# Check if we're expecting a remote branch
git ls-remote --exit-code --heads origin $BUILDKITE_BRANCH
bk=$?

if [ $bk -ne 0 ]; then
    buildkite-agent annotate \
        --append \
        --context 'branch-comparison' \
        "No branches produced - aborting"
    exit 0
fi

# Let's sleep a few minutes to let Jenkins catch-up
sleep 3m

git ls-remote --exit-code --heads origin $JENKINS_BRANCH
jen=$?

if [ $jen -ne 0 ]; then
    buildkite-agent annotate \
        --append \
        --context 'branch-comparison' \
        "[Jenkins branch](https://github.com/elastic/built-docs/tree/$JENKINS_BRANCH) not found in time - aborting"
    exit 0
fi

echo "Fetching Jenkins branch"
git fetch origin $JENKINS_BRANCH:$JENKINS_BRANCH

echo "Fetching Buildkite branch"
git fetch origin $BUILDKITE_BRANCH:$BUILDKITE_BRANCH

git --no-pager log -1 --format=%ct $JENKINS_BRANCH
jen=$?
git --no-pager log -1 --format=%ct $BUILDKITE_BRANCH
bk=$?


branches_age_diff=`expr $bk - $jen`
echo "Branches age difference (s) is $branches_age_diff"
if [ "$branches_age_diff" -gt 1800 ]; then
    buildkite-agent annotate --append --context 'branch-comparison' "<br>Jenkins and Buildkite branches are more than 30 minutes apart - skipping comparison"
    exit 0
fi

echo "Comparing the two branches, excluding branches.yaml changes, and changes with /tmp or <lastmod> in them"
diff_out=`git diff $BUILDKITE_BRANCH..$JENKINS_BRANCH -- . ':(exclude)html/branches.yaml' | grep -v "\-\-\-" | grep -E "^\-|Binary" | grep -vE "\/tmp|<lastmod>"`
retVal=$?

if [ $retVal -eq 0 ]; then
  buildkite-agent annotate --append --style 'warning' --context 'branch-comparison' '<br><span class="red">Branches differ</span>'
  buildkite-agent meta-data set "bk-jenkins-branch-comparison" "different"
  echo $diff_out
else
  buildkite-agent annotate --append --style 'success' --context 'branch-comparison' '<br><span class="green">Branches are identical</span>'
  buildkite-agent meta-data set "bk-jenkins-branch-comparison" "identical"
fi

