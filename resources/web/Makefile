# We expect this to be run in the a docker container managed by
#   build_docs --self-test

SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: jest

.PHONY: test_watch
test_watch: tests
	# /node_modules/parcel/bin/cli.js watch ./docs_js/__tests__/**/* ./docs_js/__tests__/* -d ./tests/ --target node &
	/node_modules/jest/bin/jest.js ./tests/** --watch

.PHONY: jest
jest: tests
	/node_modules/jest/bin/jest.js ./tests/**

.PHONY: tests
tests:
	rm -rf tests
	/node_modules/parcel/bin/cli.js build ./docs_js/__tests__/**/* ./docs_js/__tests__/* -d ./tests/ --target node --no-minify --no-source-maps
