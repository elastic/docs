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
	rspec \
	style \
	sub_dir keep_hash_and_sub_dir \
	multi_branch

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
	rspec

# Build the docs into a temporary directory
define BD_DUMMY=
/docs_build/build_docs.pl --in_standard_docker --out /tmp/dummy
endef

.PHONY: simple_all
simple_all:
	# Test the simplest possible `--all` invocation
	rm -rf $(TMP)
	$(BUILD_MINIMAL_ALL)
	$(call MINIMAL_ALL_EXPECTED_FILES,init)

.PHONY: sub_dir
sub_dir:
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
		--sub_dir source:master:$(TMP)/to_sub | tee $(TMP)/out
	$(call GREP,'Test book: Building master...',$(TMP)/out)
	$(call GREP,'Test book: Finished master',$(TMP)/out)
	$(call GREP,'Test book: Copying master to current',$(TMP)/out)
	$(call MINIMAL_ALL_EXPECTED_FILES,'local changes')

.PHONY: keep_hash_and_sub_dir
keep_hash_and_sub_dir:
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
		--conf $(TMP)/conf.yaml | tee $(TMP)/out
	$(call GREP,'Test book: Building master...',$(TMP)/out)
	$(call GREP,'Test book: Finished master',$(TMP)/out)
	$(call GREP,'Test book: Copying master to current',$(TMP)/out)
	$(call GREP,'Pushing changes',$(TMP)/out)

	# Move a "bad" file into source2 so we can be sure we're not picking it up
	cp ../README.asciidoc $(TMP)/source2/index.asciidoc
	cd $(TMP)/source2 && \
		git add . && \
		git commit -m 'README'

	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--keep_hash | tee $(TMP)/out
	$(call NOT_CONTAIN,'Test book',$(TMP)/out)
	$(call GREP,'No changes to push',$(TMP)/out)

	# Setup the directory we'd like to substitute
	mkdir -p $(TMP)/to_sub/docs
	cp includes_source2.asciidoc $(TMP)/to_sub/docs/index.asciidoc
	echo "extra extra extra" >> $(TMP)/to_sub/docs/index.asciidoc

	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--keep_hash --sub_dir source1:master:$(TMP)/to_sub | tee $(TMP)/out
	$(call GREP,'Test book: Building master...',$(TMP)/out)
	$(call GREP,'Test book: Finished master',$(TMP)/out)
	$(call GREP,'Test book: Copying master to current',$(TMP)/out)
	$(call GREP,'Pushing changes',$(TMP)/out)

	git clone $(TMP)/dest.git $(TMP)/dest
	$(call GREP,'extra extra extra',$(TMP)/dest/html/test/current/_chapter.html)

	# Add new repo to conf file and rebuild. We shouldn't use the repo but
	# should still get a forced rebuild.
	$(call INIT_REPO_WITH_FILE,$(TMP)/source3,minimal.asciidoc,totally_not_used.asciidoc)
	sed -riE 's|^(\s+)source2:|\1source3: $(TMP)/source3\n\1source2:|' $(TMP)/conf.yaml
	echo "            -"                          >> $(TMP)/conf.yaml
	echo "                repo:   source3"        >> $(TMP)/conf.yaml
	echo "                path:   not_used.asciidoc" >> $(TMP)/conf.yaml
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--keep_hash --sub_dir source1:master:$(TMP)/to_sub | tee $(TMP)/out
	$(call GREP,'Test book: Building master...',$(TMP)/out)
	$(call GREP,'Test book: Finished master',$(TMP)/out)
	$(call GREP,'Test book: Copying master to current',$(TMP)/out)
	# Except git will pick up that we didn't change anything, so we won't push.
	$(call GREP,'No changes to push',$(TMP)/out)
	$(call NOT_CONTAIN,'Pushing changes',$(TMP)/out)

.PHONY: multi_branch
multi_branch:
	# Tests for how we rebuild books with multiple branches

	# When the book hasn't been built before we build all branches
	rm -rf $(TMP)
	$(call INIT_REPO_WITH_FILE,$(TMP)/source,minimal.asciidoc,docs/index.asciidoc)
	cd $(TMP)/source && git checkout -b prev
	git init --bare $(TMP)/dest.git

	sed 's|--tmp--|$(TMP)|' multi_branch.yaml > $(TMP)/conf.yaml
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml | tee $(TMP)/out
	$(call GREP,'Test book: Building master...',$(TMP)/out)
	$(call GREP,'Test book: Finished master',$(TMP)/out)
	$(call GREP,'Test book: Building prev...',$(TMP)/out)
	$(call GREP,'Test book: Finished prev',$(TMP)/out)
	$(call GREP,'Test book: Copying master to current',$(TMP)/out)
	$(call GREP,'Test book: Writing versions TOC',$(TMP)/out)
	$(call GREP,'Pushing changes',$(TMP)/out)

	git clone $(TMP)/dest.git $(TMP)/dest
	# The main index links to the current version
	$(call GREP,'<a class="ulink" href="test/current/index.html" target="_top">Test book \[master\]</a>',$(TMP)/dest/html/index.html)
	$(call GREP,'<a class="ulink" href="test/index.html" target="_top">other versions</a>',$(TMP)/dest/html/index.html)
	# And the book's index links to all versions
	$(call GREP,'<a class="ulink" href="current/index.html" target="_top">Test book: master (current)</a>',$(TMP)/dest/html/test/index.html)
	$(call GREP,'<a class="ulink" href="prev/index.html" target="_top">Test book: prev</a>',$(TMP)/dest/html/test/index.html)
	# And all versions have been built
	[ -s $(TMP)/dest/html/test/current/index.html ]
	[ -s $(TMP)/dest/html/test/master/index.html ]
	[ -s $(TMP)/dest/html/test/prev/index.html ]

	# When one of the non-current branches has changed we rebuild it but do not
	# copy the current branch
	cd $(TMP)/source && \
		git checkout prev && \
		echo "changed" >> docs/index.asciidoc && \
		git add . && \
		git commit -m "change"
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml | tee $(TMP)/out
	$(call NOT_CONTAIN,'Test book: Building master...',$(TMP)/out)
	$(call NOT_CONTAIN,'Test book: Finished master',$(TMP)/out)
	$(call GREP,'Test book: Building prev...',$(TMP)/out)
	$(call GREP,'Test book: Finished prev',$(TMP)/out)
	$(call NOT_CONTAIN,'Test book: Copying master to current',$(TMP)/out)
	$(call GREP,'Test book: Writing versions TOC',$(TMP)/out)
	$(call GREP,'Pushing changes',$(TMP)/out)

	# When the current branch has changed we rebuild it and copy it to the
	# current branch
	cd $(TMP)/source && \
		git checkout master && \
		echo "changed" >> docs/index.asciidoc && \
		git add . && \
		git commit -m "change"
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml | tee $(TMP)/out
	$(call GREP,'Test book: Building master...',$(TMP)/out)
	$(call GREP,'Test book: Finished master',$(TMP)/out)
	$(call NOT_CONTAIN,'Test book: Building prev...',$(TMP)/out)
	$(call NOT_CONTAIN,'Test book: Finished prev',$(TMP)/out)
	$(call GREP,'Test book: Copying master to current',$(TMP)/out)
	$(call GREP,'Test book: Writing versions TOC',$(TMP)/out)
	$(call GREP,'Pushing changes',$(TMP)/out)

define SETUP_MINIMAL_ALL=
	# First build a repository to use as the source.
	$(call INIT_REPO_WITH_FILE,$(TMP)/source,minimal.asciidoc,index.asciidoc)

	# Initialize a bare repository that the docs build process can use as a
	# remote. It is used to pushing to github but it can push to a remote on
	# the filesystem just fine.
	git init --bare $(TMP)/dest.git

	# Setup the config
	sed 's|--tmp--|$(TMP)|' small_conf.yaml > $(TMP)/conf.yaml
endef

define BUILD_MINIMAL_ALL=
	# Builds `--all` docs using a "minimal" source file
	$(SETUP_MINIMAL_ALL)
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml | tee $(TMP)/out
	$(call GREP,'Test book: Building master...',$(TMP)/out)
	$(call GREP,'Test book: Finished master',$(TMP)/out)
	$(call GREP,'Test book: Copying master to current',$(TMP)/out)
	$(call GREP,'Test book: Writing redirect to current branch...',$(TMP)/out)
endef

define MINIMAL_ALL_EXPECTED_FILES=
	# Checks that $(TMP)/dest contains the expected result of building the
	# "minimal" source file. $(1) is the commit message that shuold be in
	# revision.txt
	git clone $(TMP)/dest.git $(TMP)/dest
	[ -s $(TMP)/dest/redirects.conf ]
	[ -s $(TMP)/dest/html/branches.yaml ]
	$(call GREP,$(1),$(TMP)/dest/html/revision.txt)
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
		echo "can't find \'$(2)\'"; \
		ls $$(dirname $(2)); \
		false; \
	}
	grep -q $(1) $(2) || { \
		echo "Couldn't" find \'$(1)\' in \'$(2)\':; \
		cat $(2); \
		false; \
	}
endef

define NOT_CONTAIN=
	# grep for a string in a file, outputting the whole file if there *is*
	# a match.
	[ -e $(2) ] || { \
		echo "can't find \'$(2)\'"; \
		ls $$(dirname $(2)); \
		false; \
	}
	set +e; grep -q $(1) $(2); test $$? -ne 0 || { \
		echo Found \'$(1)\' in \'$(2)\':; \
		grep --color $(1) $(2); \
		false; \
	}
endef