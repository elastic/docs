#!/bin/bash

# Build the docker image for the air gapped docs.

set -eo pipefail

export AIR_GAPPED=docker.elastic.co/docs-private/bk_air_gapped:latest

cd $(git rev-parse --show-toplevel)

if [[ ! -d /opt/git-mirrors/built-docs.git ]]; then
  echo "/opt/git-mirrors/built-docs.git must exist and contain a reference clone of the built-docs repo"
  exit 1
fi

# Get an up to date copy of the repo
mkdir air_gapped/work
git clone --reference /opt/git-mirrors/built-docs.git --dissociate \
  --depth 2 --branch master --bare \
  git@github.com:elastic/built-docs.git air_gapped/work/target_repo.git

GIT_DIR=air_gapped/work/target_repo.git git fetch

# Build the images
DOCKER_BUILDKIT=1 docker build -t "$AIR_GAPPED" -f air_gapped/Dockerfile .
