#!/bin/bash

set -euo pipefail

cd $(git rev-parse --show-toplevel)

echo "Building images for test execution"
for IMAGE in build py_test node_test ruby_test integ_test diff_tool; do
  echo Building $IMAGE
  ./build_docs --docker-build $IMAGE
done

make
