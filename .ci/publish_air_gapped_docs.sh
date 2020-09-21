#!/bin/bash

set -eo pipefail

cd "$(git rev-parse --show-toplevel)"
source ./air_gapped/build.sh
docker push "$AIR_GAPPED"
