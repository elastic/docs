# We expect this to be run in the a docker container managed by
#   build_docs --self-test

SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: jest

.PHONY: jest
jest:
	/node_modules/jest/bin/jest.js ./__test__/**
