#!/bin/bash

set -eo pipefail

# Uncomment me to test with docker.
# JENKINS_HOME=/var/lib/jenkins

# Use Jenkin's home as our home because that is where the ssh
# known hosts file lives.
export HOME=$JENKINS_HOME

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
        -e GITHUB_TOKEN=$GITHUB_TOKEN \
        -v ~/.git-references:/var/lib/jenkins/.git-references:cached,ro \
        -e CACHE_DIR=/var/lib/jenkins/.git-references \
        $IMAGE node /docs_build/preview/clean.js $REPO'
