#!/bin/bash

set -eo pipefail

cd $(git rev-parse --show-toplevel)
source ./air_gapped/build.sh
docker tag $AIR_GAPPED push.$AIR_GAPPED
docker push push.$AIR_GAPPED
