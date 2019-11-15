#!/bin/bash

set -eo pipefail

# Configure the git author and committer information. The tests expect there
# to be *something* set ut don't care what it is.
export GIT_AUTHOR_NAME='Jenkins CI'
export GIT_AUTHOR_EMAIL='jenkins@elasticsearch-ci.elastic.co'
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

cd $(git rev-parse --show-toplevel)
make
