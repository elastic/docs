#!/bin/bash

set -eo pipefail

export AIR_GAPPED=docker.elastic.co/docs/air_gapped:latest
./air_gapped/build.sh
docker tag $AIR_GAPPED push.$AIR_GAPPED
docker push push.$AIR_GAPPED
