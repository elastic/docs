# We expect this to be run in the a docker container managed by
#   build_docs --self-test

SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: jest

.PHONY: jest
jest:
	rm -rf tests
	/node_modules/parcel/bin/cli.js build ./docs_js/__tests__/* -d ./tests/ --target node --no-minify --no-source-maps
	/node_modules/jest/bin/jest.js ./tests/
