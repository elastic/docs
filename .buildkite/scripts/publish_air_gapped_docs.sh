#!/bin/bash
set -eo pipefail

source ./air_gapped/build_bk.sh
echo $DOCKER_PASSWORD |  docker login --username $DOCKER_USERNAME --password-stdin docker.elastic.co
echo "Pushing doc to $AIR_GAPPED"
docker push "$AIR_GAPPED"
