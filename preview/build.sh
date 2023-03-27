#!/bin/bash

# Build the docker image for the docs preview.

set -eo pipefail

export IMAGE=docker.elastic.co/docs/preview
export VERSION=17

cd $(git rev-parse --show-toplevel)
./build_docs --docker-build build
DOCKER_BUILDKIT=1 docker build -t $IMAGE:$VERSION -f preview/Dockerfile .

docker tag $IMAGE:$VERSION $IMAGE:latest

# docker push $IMAGE:$VERSION
# docker push $IMAGE:latest
