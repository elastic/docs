#!/bin/bash

set -e

cd $(git rev-parse --show-toplevel)
source ./preview/build.sh
docker tag $PREVIEW push.$PREVIEW
docker push push.$PREVIEW
