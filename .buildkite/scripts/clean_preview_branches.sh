#!/bin/bash
set -eo pipefail

export REPO=git@github.com:elastic/built-docs.git
export IMAGE=docker.elastic.co/docs/build:latest

# Temporary workaround until we can move to HTTPS auth
vault read -field=private-key secret/ci/elastic-docs/elasticmachine-ssh-key > "$HOME/.ssh/id_rsa"
vault read -field=public-key secret/ci/elastic-docs/elasticmachine-ssh-key > "$HOME/.ssh/id_rsa.pub"
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts"
chmod 600 "$HOME/.ssh/id_rsa"

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
