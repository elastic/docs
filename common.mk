SHELL = /bin/bash -eu -o pipefail
TOP = $(shell git rev-parse --show-toplevel)
DOCKER = $(TOP)/build_docs --docker-run
