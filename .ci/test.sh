#!/bin/bash

set -eo pipefail

cd $(git rev-parse --show-toplevel)

# It'd be a real shame if we couldn't build the packer cache the morning after
# we merge. So let's test that. We'll use the images that it builds to run the
# rests of the tests anyway.
echo "Building packer cache"
./.ci/packer_cache.sh

make
