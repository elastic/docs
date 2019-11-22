#!/bin/bash

# Build the docker image for the docs preview.

set -eo pipefail

export PREVIEW=docker.elastic.co/docs/preview:15

cd $(git rev-parse --show-toplevel)
./build_docs --docker-build build
DOCKER_BUILDKIT=1 docker build -t $PREVIEW -f preview/Dockerfile .

