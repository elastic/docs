#!/bin/bash

# Build the docker image for the docs preview.

set -eo pipefail

export PREVIEW=docker.elastic.co/docs/preview:15

cd $(git rev-parse --show-toplevel)
./build_docs --just-build-image
DOCKER_BUILDKIT=1 docker build -t $PREVIEW -f preview/Dockerfile .

