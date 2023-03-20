include ../common.mk

.PHONY: check
check: style rspec

.PHONY: style
style: pycodestyle rubocop

.PHONY: pycodestyle
pycodestyle: html_diff
	$(DOCKER) py_test pycodestyle html_diff

.PHONY: rubocop
rubocop:
	$(DOCKER) ruby_test rubocop

.PHONY: rspec
rspec:
	$(DOCKER) integ_test rspec
