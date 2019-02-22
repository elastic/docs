# We expect this to be run in the a docker container managed by
#   build_docs --self-test

SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: unit_test integration_test

.PHONY: unit_test
unit_test: style asciidoctor_check

.PHONY: style
style: build_docs
	pycodestyle build_docs

.PHONY: asciidoctor_check
asciidoctor_check:
	$(MAKE) -C resources/asciidoctor

.PHONY: integration_test
integration_test:
	$(MAKE) -C integtest
