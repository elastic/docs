SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: rspec style

.PHONY: style
style: pycodestyle rubocop

.PHONY: pycodestyle
pycodestyle: html_diff
	pycodestyle html_diff

.PHONY: rubocop
rubocop:
	rubocop

.PHONY: rspec
rspec:
	rspec -e '--sub_dir'
