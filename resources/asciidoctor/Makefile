include ../../common.mk

.PHONY: check
check: rspec rubocop

.PHONY: rspec
rspec:
	$(DOCKER) rspec

.PHONY: rubocop
rubocop:
	$(DOCKER) rubocop
