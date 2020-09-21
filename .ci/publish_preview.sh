#!/bin/bash

set -eo pipefail

cd "$(git rev-parse --show-toplevel)"
source ./preview/build.sh
docker push "$PREVIEW"
