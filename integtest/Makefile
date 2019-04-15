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
	minimal_same_files \
	includes_expected_files includes_same_files \
	emdash_expected_files emdash_same_files \
	beta_same_files \
	experimental_expected_files experimental_same_files \
	missing_include_fails_asciidoc missing_include_fails_asciidoctor \
	adoc_same_files \
	empty_table_cell_expected_files empty_table_cell_same_files \
	xpack_chapter_expected_files xpack_chapter_same_files \
	xpack_part_expected_files xpack_part_same_files \
	xpack_section_expected_files xpack_section_same_files \
	xpack_float_expected_files xpack_float_same_files \
	migration_warnings \
	readme_expected_files readme_same_files \
	simple_all \
	relative_conf_file \
	new_repo new_book \
	keep_hash keep_hash_new_repo keep_hash_new_book \
	sub_dir keep_hash_and_sub_dir \
	multi_branch \
	open_all \
	missing_index

.PHONY: style
style: pycodestyle rubocop

.PHONY: pycodestyle
pycodestyle: html_diff
	pycodestyle html_diff

.PHONY: rubocop
rubocop:
	rubocop --cache false

.PHONY: rspec
rspec:
	rspec

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
experimental_expected_files: /tmp/experimental_asciidoc
	$(STANDARD_EXPECTED_FILES)
	[ -s $^/images/icons/warning.png ]

.PHONY: xpack_chapter_expected_files
xpack_chapter_expected_files: /tmp/xpack_chapter_asciidoc
	$(STANDARD_EXPECTED_FILES)
	$(call GREP,'Chapter<a[^>]*>edit</a><a class="xpack_tag" href="/subscriptions">',$^/_chapter.html)
	$(call NOT_CONTAIN,'Floater<a[^>]*>edit</a><a class="xpack_tag" href="/subscriptions">',$^/_chapter.html)
	$(call NOT_CONTAIN,'Section<a[^>]*>edit</a><a class="xpack_tag" href="/subscriptions">',$^/_section.html)

.PHONY: xpack_part_expected_files
xpack_part_expected_files: /tmp/xpack_part_asciidoc
	$(STANDARD_EXPECTED_FILES)
	$(call GREP,'Part<a[^>]*>edit</a><a class="xpack_tag" href="/subscriptions">',$^/_part.html)
	$(call NOT_CONTAIN,'Floater<a[^>]*>edit</a><a class="xpack_tag" href="/subscriptions">',$^/_chapter.html)

.PHONY: xpack_section_expected_files
xpack_section_expected_files: /tmp/xpack_section_asciidoc
	$(STANDARD_EXPECTED_FILES)
	$(call GREP,'Section<a[^>]*>edit</a><a class="xpack_tag" href="/subscriptions">',$^/_section.html)
	$(call NOT_CONTAIN,'Floater<a[^>]*>edit</a><a class="xpack_tag" href="/subscriptions">',$^/_section.html)

.PHONY: xpack_float_expected_files
xpack_float_expected_files: /tmp/xpack_float_asciidoc
	$(STANDARD_EXPECTED_FILES)
	$(call GREP,'Floater</span><a[^>]*>edit</a><a class="xpack_tag" href="/subscriptions">',$^/_chapter.html)

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

.PHONY: migration_warnings
migration_warnings: migration_warnings.asciidoc
	set +e; \
		$(BD_DUMMY) --asciidoctor --doc migration_warnings.asciidoc > /tmp/out 2>&1; \
		test $$? -eq 255
	$(call GREP,"WARNING: migration_warnings.asciidoc: line 7: MIGRATION: code block end doesn't match start",/tmp/out)
	$(BD_DUMMY) --asciidoctor --doc migration_warnings.asciidoc --suppress_migration_warnings

/tmp/readme_asciidoc: /docs_build/README.asciidoc
	$(BD) --doc /docs_build/README.asciidoc

/tmp/readme_asciidoctor: /docs_build/README.asciidoc
	$(BD) --asciidoctor --doc /docs_build/README.asciidoc

/tmp/adoc_asciidoc: minimal.adoc
	$(BD) --chunk 1 --doc $^

/tmp/adoc_asciidoctor: minimal.adoc
	$(BD) --chunk 1 --asciidoctor --doc $^

# These don't declare dependencies because we don't know in general which files
# are needed to build which asciidoc files.
.PRECIOUS: /tmp/%_asciidoc     # don't try to remove the directory. you can't
/tmp/%_asciidoc:
	$(BD) --chunk 1 --doc $*.asciidoc

.PRECIOUS: /tmp/%_asciidoctor  # don't try to remove the directory. you can't
/tmp/%_asciidoctor:
	$(BD) --chunk 1 --asciidoctor --doc $*.asciidoc

.PHONY: simple_all
simple_all:
	# Test the simplest possible `--all` invocation
	rm -rf $(TMP)
	$(BUILD_MINIMAL_ALL)
	$(call MINIMAL_ALL_EXPECTED_FILES,init)

.PHONY: relative_conf_file
relative_conf_file:
	# Make sure that using a relative referece to the --conf file works.
	rm -rf $(TMP)
	$(SETUP_MINIMAL_ALL)
	cd $(TMP) && \
		/docs_build/build_docs.pl --in_standard_docker --all --push \
			--target_repo $(TMP)/dest.git \
			--conf conf.yaml
	$(call MINIMAL_ALL_EXPECTED_FILES,init)

.PHONY: new_repo
new_repo:
	# Test that `--all` works when you add a new repo to a book that used to
	# only have a single repo
	rm -rf $(TMP)
	$(BUILD_MINIMAL_ALL)

	# Replace the minimal documentation in the source repo with one that
	# references the second repo
	sed -e 's|../||' includes_source2.asciidoc > $(TMP)/source/index.asciidoc
	cat $(TMP)/source/index.asciidoc
	cd $(TMP)/source && \
		git add . && \
		git commit -m 'includes source2'
	# Add new repo to conf file
	$(call INIT_REPO_WITH_FILE,$(TMP)/source2,included.asciidoc,index.asciidoc)
	sed -riE 's|^(\s+)source:|\1source2: $(TMP)/source2\n\1source:|' $(TMP)/conf.yaml
	echo "            -"                          >> $(TMP)/conf.yaml
	echo "                repo:   source2"        >> $(TMP)/conf.yaml
	echo "                path:   index.asciidoc" >> $(TMP)/conf.yaml

	# Build the book wit hthe new repo
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml | tee $(TMP)/out
	$(call GREP,'Test book',$(TMP)/out)
	$(call NOT_CONTAIN,'No changes to push',$(TMP)/out)

	git clone $(TMP)/dest.git $(TMP)/dest
	$(call GREP,'I am tiny.',$(TMP)/dest/html/test/current/_chapter.html)

.PHONY: new_book
new_book:
	# Test that `--all` works when you add a new book to the list
	rm -rf $(TMP)
	$(BUILD_MINIMAL_ALL)

	# Add a new book
	echo "    -"                                  >> $(TMP)/conf.yaml
	echo "        title:      Test book 2"        >> $(TMP)/conf.yaml
	echo "        prefix:     test2"              >> $(TMP)/conf.yaml
	echo "        current:    master"             >> $(TMP)/conf.yaml
	echo "        branches:   [ master ]"         >> $(TMP)/conf.yaml
	echo "        index:      index.asciidoc"     >> $(TMP)/conf.yaml
	echo "        tags:       test tag"           >> $(TMP)/conf.yaml
	echo "        subject:    Test"               >> $(TMP)/conf.yaml
	echo "        sources:"                       >> $(TMP)/conf.yaml
	echo "            -"                          >> $(TMP)/conf.yaml
	echo "                repo:   source"         >> $(TMP)/conf.yaml
	echo "                path:   index.asciidoc" >> $(TMP)/conf.yaml

	# Adding a new book should cause that book to build
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml | tee $(TMP)/out
	$(call GREP,'Test book 2',$(TMP)/out)
	$(call NOT_CONTAIN,'No changes to push',$(TMP)/out)

	git clone $(TMP)/dest.git $(TMP)/dest
	$(call GREP,'minimal viable asciidoc',$(TMP)/dest/html/test2/current/_chapter.html)

.PHONY: keep_hash
keep_hash:
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
	$(call NOT_CONTAIN,'Test book',$(TMP)/out)
	$(call GREP,'No changes to push',$(TMP)/out)

	# We expact the same files as the minimal because the changes that we
	# made shouldn't be included
	$(call MINIMAL_ALL_EXPECTED_FILES,init)

.PHONY: keep_hash_new_repo
keep_hash_new_repo:
	# Test that `--all --keep_hash` doesn't pull new updates
	rm -rf $(TMP)
	$(BUILD_MINIMAL_ALL)

	# Add new repo to conf file
	$(call INIT_REPO_WITH_FILE,$(TMP)/source2,minimal.asciidoc,totally_not_used.asciidoc)
	sed -riE 's|^(\s+)source:|\1source2: $(TMP)/source2\n\1source:|' $(TMP)/conf.yaml
	echo "            -"                          >> $(TMP)/conf.yaml
	echo "                repo:   source2"        >> $(TMP)/conf.yaml
	echo "                path:   not_used.asciidoc" >> $(TMP)/conf.yaml

	# Rebuild the docs with --keep_hash which should ignore the new repo
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--keep_hash | tee $(TMP)/out
	$(call NOT_CONTAIN,'Test book',$(TMP)/out)
	$(call GREP,'No changes to push',$(TMP)/out)

	# We expact the same files as the minimal because we didn't make
	# any changes
	$(call MINIMAL_ALL_EXPECTED_FILES,init)

.PHONY: keep_hash_new_book
keep_hash_new_book:
	# Test that `--all --keep_hash` doesn't pull new updates
	rm -rf $(TMP)
	$(BUILD_MINIMAL_ALL)

	# Add a new book
	echo "    -"                                  >> $(TMP)/conf.yaml
	echo "        title:      Test book 2"        >> $(TMP)/conf.yaml
	echo "        prefix:     test2"              >> $(TMP)/conf.yaml
	echo "        current:    master"             >> $(TMP)/conf.yaml
	echo "        branches:   [ master ]"         >> $(TMP)/conf.yaml
	echo "        index:      index.asciidoc"     >> $(TMP)/conf.yaml
	echo "        tags:       test tag"           >> $(TMP)/conf.yaml
	echo "        subject:    Test"               >> $(TMP)/conf.yaml
	echo "        sources:"                       >> $(TMP)/conf.yaml
	echo "            -"                          >> $(TMP)/conf.yaml
	echo "                repo:   source"         >> $(TMP)/conf.yaml
	echo "                path:   index.asciidoc" >> $(TMP)/conf.yaml

	# If we build the all the books with --keep_hash we shouldn't rebuild
	# any books because the new book wasn't built last time.
	/docs_build/build_docs.pl --in_standard_docker --all --push \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml \
		--keep_hash | tee $(TMP)/out
	$(call NOT_CONTAIN,'Test book 2',$(TMP)/out)
	# But we *will* rebuild the table of contents so we get the book in the
	# list. That is unfortunate but isn't too big a deal.
	$(call GREP,'Pushing changes',$(TMP)/out)

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

.PHONY: open_all
open_all:
	# Test that `--all --open` starts nginx in a usable way.
	rm -rf $(TMP)
	$(SETUP_MINIMAL_ALL)
	/docs_build/build_docs.pl --in_standard_docker --all \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml --open | tee $(TMP)/out &
	curl -I --retry 10 --retry-connrefused http://127.0.0.1:8000/guide/
	mkdir $(TMP)/guide
	curl -sS http://127.0.0.1:8000/guide/ > $(TMP)/guide/index.html
	$(call GREP,'Test book',$(TMP)/guide/index.html)
	curl -sSI http://127.0.0.1:8000/guide/reference/setup > $(TMP)/guide/rdir
	$(call GREP,'301 Moved Permanently',$(TMP)/guide/rdir)
	$(call GREP,'Location: http://localhost:8000/guide/en/elasticsearch/reference/current/setup.html',$(TMP)/guide/rdir)
	kill -QUIT $$(cat /run/nginx/nginx.pid)

.PHONY: missing_index
missing_index:
	rm -rf $(TMP)
	$(call INIT_REPO_WITH_FILE,$(TMP)/source,minimal.asciidoc,docs/not_the_index.asciidoc)
	git init --bare $(TMP)/dest.git
	sed -e 's|--tmp--|$(TMP)|' \
		-e 's|path:   index.asciidoc|path:   docs|' \
		-e 's|index:      index.asciidoc|index:      foo/index.asciidoc|' \
		small_conf.yaml > $(TMP)/conf.yaml
	set +e; /docs_build/build_docs.pl --in_standard_docker --all \
		--target_repo $(TMP)/dest.git \
		--conf $(TMP)/conf.yaml > $(TMP)/out 2>&1; \
		\
		test $$? -eq 2
	$(call GREP,'Can'"'"'t find index',$(TMP)/out)
	$(call GREP,'foo/index.asciidoc',$(TMP)/out)


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