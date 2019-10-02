#!/bin/bash

# Build the docker image for the air gapped docs.

set -eo pipefail

if [[ ! -d ~/.git-references/built-docs.git ]]; then
  echo "~/.git-references/built-docs.git must exist and contain a reference clone of the built-docs repo"
  exit 1
fi

# Get an up to date copy of the repo
rm -rf air_gapped/work
mkdir air_gapped/work
git clone --reference ~/.git-references/built-docs.git --dissociate \
  --depth 2 --branch master --bare \
  git@github.com:elastic/built-docs.git air_gapped/work/target_repo.git
GIT_DIR=air_gapped/work/target_repo.git git fetch

# Build the images
./build_docs --just-build-image
docker build -t docker.elastic.co/docs/preview:10 -f preview/Dockerfile .
# Use buildkit here to pick up the customized dockerignore file
DOCKER_BUILDKIT=1 docker build -t docker.elastic.co/docs-private/air_gapped:latest -f air_gapped/Dockerfile .
