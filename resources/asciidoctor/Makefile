include ../../common.mk

.PHONY: check
check: rspec rubocop

.PHONY: rspec
rspec:
	$(DOCKER) ruby_test rspec

.PHONY: rubocop
rubocop:
	$(DOCKER) ruby_test rubocop
