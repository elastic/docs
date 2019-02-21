SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: readme_expected_files readme_same_files includes_same_files

.PHONY: readme_expected_files
readme_expected_files: /tmp/readme_asciidoc
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

.PHONY: readme_same_files
readme_same_files: /tmp/readme_asciidoc /tmp/readme_asciidoctor
	# The `grep -v snippets` is a known issue to be resolved "soon"
	diff \
		<(cd /tmp/readme_asciidoc    && find * -type f | sort \
			| grep -v snippets/blocks \
		) \
		<(cd /tmp/readme_asciidoctor && find * -type f | sort)

.PHONY: includes_same_files
includes_same_files: /tmp/includes_asciidoc /tmp/includes_asciidoctor
	diff \
		<(cd /tmp/includes_asciidoc    && find * -type f | sort) \
		<(cd /tmp/includes_asciidoctor && find * -type f | sort)

define BD=
/docs_build/build_docs.pl --in_standard_docker --out $@
endef

/tmp/readme_asciidoc: /docs_build/README.asciidoc
	$(BD) --doc /docs_build/README.asciidoc

/tmp/readme_asciidoctor: /docs_build/README.asciidoc
	$(BD) --asciidoctor --doc /docs_build/README.asciidoc

# These don't declare dependencies because we don't know in general which files
# are needed to build which asciidoc files.
/tmp/%_asciidoc:
	$(BD) --doc $*.asciidoc

/tmp/%_asciidoctor:
	$(BD) --asciidoctor --doc $*.asciidoc
