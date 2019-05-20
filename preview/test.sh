#!/bin/bash

# Performs a quick and dirty local test on the preview. Because this runs as
# it would in k8s you'll need to `docker kill` it when you are done. We do
# have integration tests for this in integtest/spec/preview_spec.rb which are
# much faster because they don't use real data.

set -e

cd $(git rev-parse --show-toplevel)
docker build -t docker.elastic.co/docs/preview:1 -f preview/Dockerfile .
id=$(docker run --rm \
           --publish 8000:8000/tcp \
           -d \
           docker.elastic.co/docs/preview:1)
echo "Started the preview. Some useful commands:"
echo "   docker kill $id"
echo "   docker logs -tf $id"
echo "You should eventually be able to access:"
echo "   http://master.localhost:8000/guide/index.html"