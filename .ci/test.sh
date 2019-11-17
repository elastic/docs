#!/bin/bash

set -eo pipefail

cd $(git rev-parse --show-toplevel)
make
