#!/bin/bash

set -eo pipefail

cd $(git rev-parse --show-toplevel)
for IMAGE in build py_test node_test ruby_test integ_test diff_tool; do
  echo Building $IMAGE
  ./build_docs --docker-build $IMAGE
done
