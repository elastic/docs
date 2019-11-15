#!/bin/bash

set -eo pipefail

# It'd be a real shame if we couldn't build the packer cache the morning after
# we merge. So let's test that. We'll use the images that it builds to run the
# rests of the tests anyway.
echo "Building packer cache"
./.ci/packer_cache.sh

# Configure the git author and committer information. The tests expect there
# to be *something* set ut don't care what it is.
export GIT_AUTHOR_NAME='Jenkins CI'
export GIT_AUTHOR_EMAIL='jenkins@elasticsearch-ci.elastic.co'
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

cd $(git rev-parse --show-toplevel)
make
