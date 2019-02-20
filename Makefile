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
integration_test: expected_files_check same_files_check

.PHONY: expected_files_check
expected_files_check: /tmp/readme_asciidoc
	# Checking for expected html files
	[ -s $^/index.html ]
	[ -s $^/_conditions_of_use.html ]
	# Checking for copied images
	[ -s $^/resources/cat.jpg ]
	[ -s $^/images/icons/caution.png ]
	[ -s $^/images/icons/important.png ]
	[ -s $^/images/icons/note.png ]
	[ -s $^/images/icons/warning.png ]
	[ -s $^/images/icons/callouts/1.png ]
	[ -s $^/images/icons/callouts/2.png ]
	[ -s $^/snippets/blocks/1.json ]

.PHONY: same_files_check
same_files_check: /tmp/readme_asciidoc /tmp/readme_asciidoctor
	# The `grep -v snippets` is a known issue to be resolved "soon"
	diff \
		<(cd /tmp/readme_asciidoc    && find * -type f | sort \
			| grep -v snippets/blocks \
		) \
		<(cd /tmp/readme_asciidoctor && find * -type f | sort)

/tmp/readme_asciidoc:
	./build_docs.pl --in_standard_docker \
		--doc README.asciidoc --out /tmp/readme_asciidoc

/tmp/readme_asciidoctor:
	./build_docs.pl --in_standard_docker --asciidoctor \
		--doc README.asciidoc --out /tmp/readme_asciidoctor
