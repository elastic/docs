#!/bin/bash

# Performs a quick and dirty local test on the preview. Because this runs as
# it would in k8s you'll need to `docker kill` it when you are done. We do
# have integration tests for this in integtest/spec/preview_spec.rb which are
# much faster because they don't use real data but this is useful too.

set -e

cd $(git rev-parse --show-toplevel)
../infra/ansible/roles/git_fetch_reference/files/git-fetch-reference.sh git@github.com:elastic/built-docs.git
docker build -t docker.elastic.co/docs/preview:9 -f preview/Dockerfile .
id=$(docker run --rm \
          --publish 8000:8000/tcp \
          -v $HOME/.git-references:/root/.git-references \
          -d \
          docker.elastic.co/docs/preview:9 \
          /docs_build/build_docs.pl --in_standard_docker \
              --preview --reference /root/.git-references \
              --target_repo https://github.com/elastic/built-docs.git)
echo "Started the preview. Some useful commands:"
echo "   docker kill $id"
echo "   docker logs -tf $id"
echo "You should eventually be able to access:"
echo "   http://master.localhost:8000/guide/index.html"
