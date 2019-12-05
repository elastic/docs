# frozen_string_literal: true

RSpec.describe 'building all books' do
  describe '--sub_dir' do
    ##
    # Setups up a repo that looks like:
    #      master             sub_me
    # original master-------->subbed
    #        |
    #    new master
    #        |
    #  too new master
    #
    # Optionally runs the build once on the commit "new master". Then it always
    # runs the build, substituting sub_me for the master branch. If:
    # * --keep_hash isn't specified or
    # * the sub_me branch has outstanding changes or
    # * there was a merge conflict or
    # * the build wasn't run against "new master"
    # then --sub_dir will pick up the contents of the directory and the build
    # won't have "new maser" because it was forked from "original master".
    # Otherwise, --keep_hash and --sub_dir will cause the build to merge
    # "new master" and "subbed" and build against *that*.
    def self.convert_with_sub(keep_hash: true, commit_sub: true,
                              build_with_init: true,
                              cause_merge_conflict: false, premerge: false)
      convert_before do |src, dest|
        repo = setup_repo src
        setup_book src, repo
        dest.prepare_convert_all(src.conf).convert if build_with_init
        modify_master_after_build repo
        setup_sub repo, commit_sub, cause_merge_conflict, premerge
        second_convert src, repo, dest, keep_hash
      end
    end

    def self.prefix
      'docs/'
    end

    def self.setup_repo(src)
      repo = src.repo 'repo'
      repo.write "#{prefix}index.adoc", index
      repo.write "#{prefix}from_master.adoc", 'original master'
      repo.write "#{prefix}from_subbed.adoc", 'unsubbed'
      repo.commit 'original master'
      repo.write "#{prefix}from_master.adoc", 'new master'
      repo.write "#{prefix}conflict", 'from master'
      repo.commit 'new master'
      repo
    end

    def self.setup_book(src, repo)
      book = src.book 'Test'
      book.index = "#{prefix}index.adoc"
      book.source repo, 'docs'
    end

    def self.modify_master_after_build(repo)
      repo.write "#{prefix}from_master.adoc", 'too new master'
      repo.commit 'too new master'
    end

    def self.setup_sub(repo, commit_sub, cause_merge_conflict, premerge)
      repo.switch_to_branch 'HEAD~2'
      repo.switch_to_new_branch 'sub_me'
      repo.write "#{prefix}from_subbed.adoc", 'now subbed'
      repo.write "#{prefix}conflict", 'from subbed' if cause_merge_conflict
      repo.commit 'subbed' if commit_sub
      repo.merge 'master' if premerge
    end

    def self.second_convert(src, repo, dest, keep_hash)
      builder = dest.prepare_convert_all src.conf
      builder.sub_dir repo, 'master'
      builder.keep_hash if keep_hash
      builder.convert
      dest.checkout_conversion
    end

    def self.index
      <<~ASCIIDOC
        = Title

        [[chapter]]
        == Chapter

        include::from_master.adoc[]
        include::from_subbed.adoc[]
      ASCIIDOC
    end

    let(:logs) { outputs[-1] }

    shared_examples 'examples' do |master|
      file_context 'raw/test/master/chapter.html' do
        it "contains the #{master} master changes" do
          expect(contents).to include("<p>#{master} master</p>")
        end
        it 'contains the subbed changes' do
          expect(contents).to include('<p>now subbed</p>')
        end
      end
    end
    shared_examples 'contains the original master and subbed changes' do
      include_examples 'examples', 'original'
    end
    shared_examples 'contains the new master and subbed changes' do
      include_examples 'examples', 'new'
    end
    shared_examples 'contains the too new master and subbed changes' do
      include_examples 'examples', 'too new'
    end
    shared_examples 'log merge' do |path|
      it "log that it started merging [#{path}]" do
        expect(logs).to include(<<~LOGS)
          Test: Merging the subbed dir for [repo][master][#{path}] into the last successful build.
        LOGS
      end
      it "log that it merged [#{path}]" do
        expect(logs).to include(<<~LOGS)
          Test: Merged the subbed dir for [repo][master][#{path}] into the last successful build.
        LOGS
      end
    end

    describe 'without --keep_hash' do
      convert_with_sub keep_hash: false
      it "doesn't log that it won't merge because of uncommitted changes" do
        expect(logs).not_to include(<<~LOGS)
          Test: Not merging the subbed dir for [repo][master][docs] because it has uncommitted changes.
        LOGS
      end
      include_examples 'contains the original master and subbed changes'
    end
    describe 'with --keep_hash' do
      describe 'when there are uncommitted changes' do
        convert_with_sub commit_sub: false
        it "logs that it won't merge because of uncommitted changes" do
          expect(logs).to include(<<~LOGS)
            Test: Not merging the subbed dir for [repo][master][docs] because it has uncommitted changes.
          LOGS
        end
        include_examples 'contains the original master and subbed changes'
      end
      describe 'when the source is new' do
        convert_with_sub build_with_init: false
        it "log that it won't merge because the source is new" do
          expect(logs).to include(<<~LOGS)
            Test: Not merging the subbed dir for [repo][master][docs] because it is new.
          LOGS
        end
        include_examples 'contains the original master and subbed changes'
      end
      describe 'when the subbed dir can be merged' do
        convert_with_sub
        include_examples 'log merge', 'docs'
        include_examples 'contains the new master and subbed changes'
      end
      describe 'when the source path is the entire repo' do
        def self.setup_book(src, repo)
          book = src.book 'Test'
          book.index = 'docs/index.adoc'
          book.source repo, '/'
        end
        convert_with_sub
        include_examples 'log merge', '.'
        include_examples 'contains the new master and subbed changes'
      end
      describe 'when the source path has a *' do
        def self.setup_book(src, repo)
          book = src.book 'Test'
          book.index = 'docs/index.adoc'
          book.source repo, '/*/'
        end
        convert_with_sub
        include_examples 'log merge', '*'
        include_examples 'contains the new master and subbed changes'
      end
      describe 'when the source path has a deep *' do
        describe 'when the config was used for the first book' do
          def self.prefix
            'foo/bar/docs/foo/'
          end

          def self.setup_book(src, repo)
            book = src.book 'Test'
            book.index = 'foo/bar/docs/foo/index.adoc'
            book.source repo, '/foo/*/docs/*'
          end

          convert_with_sub
          include_examples 'log merge', 'foo/*/docs/*'
          include_examples 'contains the new master and subbed changes'
        end
        describe 'when the config is new' do
          # TODO: remove these parameters by overriding this sub in more places.
          def self.setup_sub(
              repo, _commit_sub, _cause_merge_conflict, _premerge
            )
            repo.switch_to_branch 'HEAD~2'
            repo.switch_to_new_branch 'sub_me'
            repo.write "#{prefix}from_subbed.adoc", <<~ASCIIDOC
              include::../foo/bar/docs/baz/foo.adoc[]
            ASCIIDOC
            repo.write 'foo/bar/docs/baz/foo.adoc', 'now subbed'
            repo.commit 'subbed'
          end

          def self.second_convert(src, repo, dest, keep_hash)
            book = src.book 'Test'
            book.source repo, '/foo/*/docs/*'
            super
          end

          convert_with_sub
          include_examples 'log merge', 'docs'
          it "log that it won't merge because the source is new" do
            expect(logs).to include(<<~LOGS)
              Test: Not merging the subbed dir for [repo][master][foo/*/docs/*] because it is new.
            LOGS
          end
          include_examples 'contains the new master and subbed changes'
        end
      end
      describe 'when the subbed dir has already been merged' do
        # This simulates what github will do if you ask it to build the "sha"
        # of the merged PR instead of the "head" of the branch.
        convert_with_sub premerge: true
        include_examples 'log merge', 'docs'
        include_examples 'contains the too new master and subbed changes'
      end
      describe 'when there is a conflict merging the subbed dir' do
        convert_with_sub cause_merge_conflict: true
        it 'logs that it failed to merge' do
          expect(logs).to include(<<~LOGS)
            Test: Failed to merge the subbed dir for [repo][master][docs] into the last successful build:
          LOGS
        end
        it 'logs the conflict' do
          expect(logs).to include(<<~LOGS)
            CONFLICT (add/add): Merge conflict in docs/conflict
          LOGS
        end
        include_examples 'contains the original master and subbed changes'
      end
      describe 'when there is more than one source using the same repo' do
        def self.setup_book(src, repo)
          book = src.book 'Test'
          book.index = 'docs/index.adoc'
          book.source repo, 'docs/index.adoc'
          book.source repo, 'docs/from_master.adoc'
          book.source repo, 'docs/from_subbed.adoc'
        end
        convert_with_sub
        include_examples 'log merge', 'docs/index.adoc'
        include_examples 'log merge', 'docs/from_master.adoc'
        include_examples 'log merge', 'docs/from_subbed.adoc'
        include_examples 'contains the new master and subbed changes'
      end
      describe 'when more than one book uses the same source' do
        def self.setup_book(src, repo)
          %w[Test Test2].each do |name|
            book = src.book name
            book.index = 'docs/index.adoc'
            book.source repo, 'docs'
          end
        end
        convert_with_sub
        include_examples 'log merge', 'docs'
        it 'logs only one merge' do
          # This asserts that we log a single merge. We *should* be using the
          # cache instead.
          expect(logs).not_to match(/Merged.+Merged/m)
        end
        include_examples 'contains the new master and subbed changes'
      end
    end
  end
end
