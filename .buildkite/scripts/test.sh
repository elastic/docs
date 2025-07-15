#!/bin/bash

set -euo pipefail

export GEM_PATH=/var/lib/gems${GEM_PATH:+:$GEM_PATH}

echo "Building images for docs test"
for IMAGE in build py_test node_test ruby_test integ_test diff_tool; do
  echo Building $IMAGE
  ./build_docs --docker-build $IMAGE
done

make
