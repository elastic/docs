SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent
TMP = /tmp/docs_integtest/$@

# Used by the test for --all
export GIT_AUTHOR_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test
export GIT_COMMITTER_EMAIL=test@example.com

.PHONY: check
check: \
	style \
	minimal_expected_files minimal_same_files \
	includes_expected_files includes_same_files \
	emdash_expected_files emdash_same_files \
	beta_expected_files beta_same_files \
	experimental_expected_files experimental_same_files \
	missing_include_fails_asciidoc missing_include_fails_asciidoctor \
	readme_expected_files readme_same_files \
	simple_all_expected_files \
	keep_hash_expected_files \
	sub_dir_expected_files \
	keep_hash_and_sub_dir_expected_files

.PHONY: style
style: html_diff
	pycodestyle html_diff

define STANDARD_EXPECTED_FILES=
	[ -s $^/index.html ]
	[ -s $^/docs.js ]
	[ -s $^/styles.css ]
	[ -s $^/template.md5 ]
endef

.PHONY: readme_expected_files
readme_expected_files: /tmp/readme_asciidoc
	$(STANDARD_EXPECTED_FILES)
	# Checking for expected html files
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

.PHONY: experimental_expected_files
beta_expected_files: /tmp/beta_asciidoc
	$(STANDARD_EXPECTED_FILES)
	[ -s $^/images/icons/warning.png ]

.PHONY: experimental_expected_files
experimental_expected_files: /tmp/experimental_asciidoc
	$(STANDARD_EXPECTED_FILES)
	[ -s $^/images/icons/warning.png ]

.PHONY: %_expected_files
%_expected_files: /tmp/%_asciidoc
	$(STANDARD_EXPECTED_FILES)

.PHONY: %_same_files
%_same_files: /tmp/%_asciidoc /tmp/%_asciidoctor
	diff \
		<(cd /tmp/$*_asciidoc    && find * -type f | sort \
			| grep -v 'snippets/' \
		) \
		<(cd /tmp/$*_asciidoctor && find * -type f | sort \
			| grep -v 'snippets/' \
		)
	for file in $$(cd /tmp/$*_asciidoc && find * -type f -name '*.html'); do \
		./html_diff /tmp/$*_asciidoc/$$file /tmp/$*_asciidoctor/$$file; \
	done
	# TODO validate the snippets have the same contents even if the files aren't the same

# Build the docs into the target
define BD=
/docs_build/build_docs.pl --in_standard_docker --out $@
endef

# Build the docs into a temporary directory
define BD_DUMMY=
/docs_build/build_docs.pl --in_standard_docker --out /tmp/dummy
endef

.PHONY: missing_include_fails_asciidoc
missing_include_fails_asciidoc: missing_include.asciidoc
	set +e; \
		$(BD_DUMMY) --doc missing_include.asciidoc > /tmp/out 2>&1; \
		test $$? -eq 255
	$(call GREP,'WARNING: missing_include.asciidoc: line 7: include file not found: /docs_build/integtest/missing.asciidoc',/tmp/out)

.PHONY: missing_include_fails_asciidoctor
missing_include_fails_asciidoctor: missing_include.asciidoc
	set +e; \
		$(BD_DUMMY) --asciidoctor --doc missing_include.asciidoc > /tmp/out 2>&1; \
		test $$? -eq 255
	$(call GREP,'ERROR: missing_include.asciidoc: line 7: include file not found: /docs_build/integtest/missing.asciidoc',/tmp/out)

/tmp/readme_asciidoc: /docs_build/README.asciidoc
	$(BD) --doc /docs_build/README.asciidoc

/tmp/readme_asciidoctor: /docs_build/README.asciidoc
	$(BD) --asciidoctor --doc /docs_build/README.asciidoc

# These don't declare dependencies because we don't know in general which files
# are needed to build which asciidoc files.
.PRECIOUS: /tmp/%_asciidoc     # don't try to remove the directory. you can't
/tmp/%_asciidoc:
	$(BD) --doc $*.asciidoc

.PRECIOUS: /tmp/%_asciidoctor  # don't try to remove the directory. you can't
/tmp/%_asciidoctor:
	$(BD) --asciidoctor --doc $*.asciidoc

.PHONY: simple_all_expected_files
simple_all_expected_files:
	# Test the simplest possible `--all` invocation
	rm -rf $(TMP)
	$(BUILD_MINIMAL_ALL)
	$(MINIMAL_ALL_EXPECTED_FILES)

.PHONY: keep_hash_expected_files
keep_hash_expected_files:
	# Test that `--all --keep_hash` doesn't pull new updates
	rm -rf $(TMP)
	$(BUILD_MINIMAL_ALL)

	# REPLACE the minimal documentation in the source repo
	cp ../README.asciidoc $(TMP)/source/index.asciidoc
	cd $(TMP)/source && \
		git add . && \
		git commit -m 'README'

	# Rebuild the docs with --keep_hash which should ignore the replacement
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--keep_hash | tee $(TMP)/out
	$(call GREP,'No changes to push',$(TMP)/out)

	# We expact the same files as the minimal because we the changes that we
	# make shouldn't be included
	$(MINIMAL_ALL_EXPECTED_FILES)

.PHONY: sub_dir_expected_file
sub_dir_expected_files:
	# Test that `--all --sub_dir` substitutes a directory for a branch of
	# a repo.
	rm -rf $(TMP)

	# We still need to build the source repo because the script wants to fetch
	# it just in case we need another branch.
	git init $(TMP)/source
	cd $(TMP)/source && git commit --allow-empty -m "empty"

	# Setup the directory we'd like to substitute
	mkdir $(TMP)/to_sub
	cp minimal.asciidoc $(TMP)/to_sub/index.asciidoc

	git init --bare $(TMP)/dest.git
	sed -e 's|--tmp--|$(TMP)|' small_conf.yaml > $(TMP)/conf.yaml
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--sub_dir source:master:$(TMP)/to_sub

	$(MINIMAL_ALL_EXPECTED_FILES)

.PHONY: keep_hash_and_sub_dir_expected_files
keep_hash_and_sub_dir_expected_files:
	# Test that `--all --keep_hash --sub_dir` keeps hashes the same for repos
	# not specified by --sub_dir but forces rebuilding all books that include
	# --sub_dir.

	rm -rf $(TMP)
	$(call INIT_REPO_WITH_FILE,$(TMP)/source1,includes_source2.asciidoc,docs/index.asciidoc)
	$(call INIT_REPO_WITH_FILE,$(TMP)/source2,included.asciidoc,index.asciidoc)
	git init --bare $(TMP)/dest.git

	sed 's|--tmp--|$(TMP)|' two_repos_conf.yaml > $(TMP)/conf.yaml
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml

	# Move a "bad" file into source2 so we can be sure we're not picking it up
	cp ../README.asciidoc $(TMP)/source2/index.asciidoc
	cd $(TMP)/source2 && \
		git add . && \
		git commit -m 'README'

	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--keep_hash | tee /tmp/out
	$(call GREP,'No changes to push',/tmp/out)

	# Setup the directory we'd like to substitute
	mkdir -p $(TMP)/to_sub/docs
	cp includes_source2.asciidoc $(TMP)/to_sub/docs/index.asciidoc
	echo "extra extra extra" >> $(TMP)/to_sub/docs/index.asciidoc

	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--keep_hash --sub_dir source1:master:$(TMP)/to_sub | tee $(TMP)/out
	$(call GREP,'Pushing changes',$(TMP)/out)

	git clone $(TMP)/dest.git $(TMP)/dest
	$(call GREP,'extra extra extra',$(TMP)/dest/html/test/current/_chapter.html)

define GREP=
	# grep for a string in a file, outputting the whole file if there isn't
	# a match.
	[ -e $(2) ] || { \
		echo "can't find $(2)"; \
		ls $$(dirname $(2)); \
		false; \
	}
	grep $(1) $(2) > /dev/null || { \
		echo "Couldn't find $(1) in $(2):"; \
		cat $(2); \
		false; \
	}
endef

define BUILD_MINIMAL_ALL=
	# Builds `--all` docs using a "minimal" source file

	# First build a repository to use as the source.
	$(call INIT_REPO_WITH_FILE,$(TMP)/source,minimal.asciidoc,index.asciidoc)

	# Initialize a bare repository that the docs build process can use as a
	# remote. It is used to pushing to github but it can push to a remote on
	# the filesystem just fine.
	git init --bare $(TMP)/dest.git

	# Actually build the docs
	sed 's|--tmp--|$(TMP)|' small_conf.yaml > $(TMP)/conf.yaml
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml
endef

define MINIMAL_ALL_EXPECTED_FILES=
	# Checks that $(1).git contains the expected result of building the
	# "minimal" source file
	git clone $(TMP)/dest.git $(TMP)/dest
	[ -s $(TMP)/dest/html/branches.yaml ]
	$(call GREP,'<a class="ulink" href="test/current/index.html" target="_top">Test book</a>',$(TMP)/dest/html/index.html)
	$(call GREP,'<meta http-equiv="refresh" content="0; url=current/index.html">',$(TMP)/dest/html/test/index.html)
	[ -s $(TMP)/dest/html/test/current/index.html ]
endef

define INIT_REPO_WITH_FILE=
	# Initializes the repo at $(1) and commits the file in $(2) with the
	# name $(3)
	git init $(1)
	mkdir -p $$(dirname $(1)/$(3))
	cp $(2) $(1)/$(3)
	cd $(1) && \
		git add . && \
		git commit -m 'init'
endef

define GREP=
	# grep for a string in a file, outputting the whole file if there isn't
	# a match.
	[ -e $(2) ] || { \
		echo "can't find $(2)"; \
		ls $$(dirname $(2)); \
		false; \
	}
	grep $(1) $(2) > /dev/null || { \
		echo "Couldn't find $(1) in $(2):"; \
		cat $(2); \
		false; \
	}
endef
