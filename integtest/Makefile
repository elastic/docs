include ../common.mk

.PHONY: check
check: rspec style

.PHONY: style
style: pycodestyle rubocop

.PHONY: pycodestyle
pycodestyle: html_diff
	$(DOCKER) pycodestyle html_diff

.PHONY: rubocop
rubocop:
	$(DOCKER) rubocop

.PHONY: rspec
rspec:
	$(DOCKER) rspec
