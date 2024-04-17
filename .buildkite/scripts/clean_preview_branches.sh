#!/bin/bash
set -eo pipefail

export REPO=git@github.com:elastic/built-docs.git
export IMAGE=docker.elastic.co/docs/build:latest

./build_docs --docker-build build
ssh-agent bash -c '
    ssh-add &&
    docker run --rm \
        -v $(pwd):/docs_build:cached,ro \
        -v ~/.ssh/known_hosts:/root/.ssh/known_hosts:cached,ro \
        -v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK:cached,ro \
        -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK \
        -e GITHUB_TOKEN=$VAULT_GITHUB_TOKEN \
        -v /opt/git-mirrors:/opt/git-mirrors:cached,ro \
        -e CACHE_DIR=/opt/git-mirrors \
        $IMAGE node /docs_build/preview/clean.js $REPO'
