#!/bin/bash

ROOT=$(dirname $(dirname $(realpath "$0")))

$ROOT/build_docs --just-build-image

