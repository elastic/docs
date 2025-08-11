include ../../common.mk

.PHONY: check
check: jest

.PHONY: jest
jest: tests
	$(DOCKER) node_test /node_modules/jest/bin/jest.js ./tests/** ./__test__/**

.PHONY: tests
tests:
	rm -rf tests
	$(DOCKER) node_test npx parcel build ./docs_js/__tests__/**/*.j{s,sx} ./docs_js/__tests__/*.j{s,sx} --dist-dir ./tests/ --no-optimize --no-source-maps
