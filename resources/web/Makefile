include ../../common.mk

.PHONY: check
check: jest

.PHONY: jest
jest: tests
	$(DOCKER) node_test /node_modules/jest/bin/jest.js ./tests/** ./__test__/**

.PHONY: tests
tests:
	rm -rf tests
	$(DOCKER) node_test sh -c 'cd /docs_build/resources/web && /node_modules/parcel/lib/bin.js build "docs_js/__tests__/**/*.js" "docs_js/__tests__/**/*.jsx" --dist-dir ./tests/ --target node --no-optimize --no-source-maps --no-scope-hoist'
