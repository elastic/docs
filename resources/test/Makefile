include ../../common.mk

.PHONY: check
check: rubocop

.PHONY: rubocop
rubocop:
	$(DOCKER) ruby_test rubocop
