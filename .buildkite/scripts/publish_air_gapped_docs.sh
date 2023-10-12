#!/bin/bash
set -eo pipefail

# Log in to docker.elastic.co.
set +x
DOCKER_USERNAME=$(vault kv get -field=username secret/ci/elastic-docs/docker.elastic.co)
DOCKER_PASSWORD=$(vault kv get -field=password secret/ci/elastic-docs/docker.elastic.co)
source .buildkite/scripts/retry.sh
retry 5 docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD docker.elastic.co
unset DOCKER_USERNAME
unset DOCKER_PASSWORD
set -x

source ./air_gapped/build_bk.sh
docker push "$AIR_GAPPED"
