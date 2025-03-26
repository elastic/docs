include ../../common.mk

.PHONY: check
check: rspec rubocop

.PHONY: rspec
rspec:
	$(DOCKER) ruby_test rspec

.PHONY: rubocop
rubocop:
	# TODO re-enable
	# $(DOCKER) ruby_test rubocop
