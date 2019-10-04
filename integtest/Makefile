SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent
TMP = /tmp/docs_integtest/$@

# Used by the test for --all
export GIT_AUTHOR_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test
export GIT_COMMITTER_EMAIL=test@example.com

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
	rspec -e "when there isn't an elastic remot"
