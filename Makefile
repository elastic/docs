# We expect this to be run in the a docker container managed by
#   build_docs --self-test

SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: build_docs_check asciidoctor_check readme_check

.PHONY: build_docs_check
build_docs_check:
	pycodestyle build_docs

.PHONY: asciidoctor_check
asciidoctor_check:
	$(MAKE) -C resources/asciidoctor

.PHONY: readme_check
readme_check: /tmp/readme
	[ -s /tmp/readme/index.html ]
	[ -s /tmp/readme/_conditions_of_use.html ]

/tmp/readme:
	./build_docs.pl --in_standard_docker --doc README.asciidoc --out /tmp/readme
