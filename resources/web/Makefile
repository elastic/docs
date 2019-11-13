include ../../common.mk

.PHONY: check
check: jest

.PHONY: jest
jest: tests
	$(DOCKER) node_test /node_modules/jest/bin/jest.js ./tests/** ./__test__/**

.PHONY: tests
tests:
	rm -rf tests
	$(DOCKER) node_test /node_modules/parcel/bin/cli.js build ./docs_js/__tests__/**/* ./docs_js/__tests__/* -d ./tests/ --target node --no-minify --no-source-maps
