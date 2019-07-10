#!/bin/bash

set -eo pipefail

# TODO pick up the image name automatically
export REPO=git@github.com:elastic/built-docs.git
export HOME=/var/lib/jenkins
export IMAGE=docker.elastic.co/docs/build:1

./build_docs --just-build-image
ssh-agent bash -c "
    ssh-add &&
    docker run --rm \
        -v $(pwd):/docs_build:cached,ro \
        -v ~/.ssh/known_hosts:/root/.ssh/known_hosts:cached,ro \
        -v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK:cached,ro \
        -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK \
        -e GITHUB_TOKEN=$GITHUB_TOKEN \
        -v ~/.git-references:/var/lib/jenkins/.git-references:cached,ro \
        -e CACHE_DIR=/var/lib/jenkins/.git-references \
        $IMAGE node /docs_build/preview/clean.js $REPO"
