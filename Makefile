# We expect this to be run in the a docker container managed by
#   build_docs --self-test

SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: unit_test integration_test

.PHONY: unit_test
unit_test: build_docs_check asciidoctor_check

.PHONY: build_docs_check
build_docs_check:
	pycodestyle build_docs

.PHONY: asciidoctor_check
asciidoctor_check:
	$(MAKE) -C resources/asciidoctor

.PHONY: integration_test
integration_test: readme_asciidoc_check readme_asciidoctor_check

.PHONY: readme_asciidoc_check
readme_asciidoc_check: /tmp/readme_asciidoc
	[ -s /tmp/readme_asciidoc/index.html ]
	[ -s /tmp/readme_asciidoc/_conditions_of_use.html ]

/tmp/readme_asciidoc:
	./build_docs.pl --in_standard_docker \
		--doc README.asciidoc --out /tmp/readme_asciidoc

.PHONY: readme_asciidoctor_check
readme_asciidoctor_check: /tmp/readme_asciidoctor
	[ -s /tmp/readme_asciidoctor/index.html ]
	[ -s /tmp/readme_asciidoctor/_conditions_of_use.html ]

/tmp/readme_asciidoctor:
	./build_docs.pl --in_standard_docker --asciidoctor \
		--doc README.asciidoc --out /tmp/readme_asciidoctor
