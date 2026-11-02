include ../../common.mk

.PHONY: check
check: test

.PHONY: test
test:
	$(DOCKER) node_test /node_modules/vitest/vitest.mjs run
