#!/bin/bash

set -e

export BUILD=docker.elastic.co/docs/build:1
export PREVIEW=docker.elastic.co/docs/preview:14

cd $(git rev-parse --show-toplevel)
./build_docs --just-build-image
DOCKER_BUILDKIT=1 docker build -t $PREVIEW -f preview/Dockerfile .
docker tag $BUILD push.$BUILD
docker push push.$BUILD
docker tag $PREVIEW push.$PREVIEW
docker push push.$PREVIEW
