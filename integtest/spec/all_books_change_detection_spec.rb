# frozen_string_literal: true

##
# Assertions about when books are rebuilt based on changes in source
# repositories or the book's configuration.
RSpec.describe 'building all books' do
  class Config
    attr_accessor :target_branch
    attr_accessor :checkout_branch
    attr_accessor :keep_hash

    def initialize(src, dest)
      @src = src
      @dest = dest
      @target_branch = nil
      @checkout_branch = nil
      @keep_hash = false
    end

    def convert_all
      conversion = @dest.prepare_convert_all @src.conf
      conversion.target_branch @target_branch if @target_branch
      conversion.keep_hash if @keep_hash
      conversion.convert
    end
  end
  describe 'change detection' do
    def self.build_twice(
        before_first_build:,
        before_second_build:
      )
      convert_before do |src, dest|
        config = Config.new src, dest
        # Allow the caller to customize the source.
        before_first_build.call(src, config)

        # Convert the first time. This should build the docs.
        config.convert_all

        # Take some action between the builds.
        before_second_build.call(src, config)

        # Convert the second time.
        config.convert_all

        # Checkout the files so we can assert about them.
        checkout = config.checkout_branch || config.target_branch
        dest.checkout_conversion branch: checkout
      end
    end

    def self.build_one_book_out_of_one_repo_twice(
        before_first_build: ->(src, config) {},
        before_second_build: ->(src, config) {}
      )
      build_twice(
        before_first_build: lambda do |src, config|
          src.book_and_repo 'repo', 'Test', 'Some text.'

          # Allow the caller to customize the source
          before_first_build.call src, config
        end,
        before_second_build: before_second_build
      )
      include_context 'build one book twice'
    end

    def self.build_one_book_out_of_one_repo_and_then_out_of_two(
        before_second_build: ->(src, config) {}
      )
      build_twice(
        before_first_build: lambda do |src, _config|
          src.book_and_repo 'repo', 'Test', 'Some text.'
        end,
        before_second_build: init_second_book_and_customize(before_second_build)
      )
      include_context 'build one book twice'
    end

    def self.init_second_book_and_customize(before_second_build)
      lambda do |src, config|
        repo2 = src.repo 'repo2'
        repo2.write 'garbage', 'junk'
        repo2.commit 'adding junk'
        src.book('Test').source repo2, 'garbage'

        before_second_build.call src, config
      end
    end

    def self.build_one_book_out_of_two_repos_twice(
        before_first_build: ->(src) {},
        before_second_build: ->(src) {}
      )
      build_twice(
        before_first_build: lambda do |src, _config|
          src.simple_include

          # Allow the caller to customize the source
          before_first_build.call src
        end,
        before_second_build: lambda do |src, _config|
          before_second_build.call src
        end
      )
      include_context 'build one book twice'
    end

    def self.build_one_book_then_two_books(
        before_second_build: ->(src, config) {}
      )
      build_twice(
        before_first_build: lambda do |src, _config|
          src.book_and_repo 'repo', 'Test', 'Some text.'
        end,
        before_second_build: lambda do |src, config|
          src.book('Test2').source src.repo('repo'), 'index.asciidoc'

          before_second_build.call src, config
        end
      )
      include_examples 'build one book then two books'
    end

    shared_context 'build one book twice' do
      context 'the first build' do
        let(:out) { outputs[0] }
        include_examples 'builds all books'
      end
      include_examples 'convert all basics'
    end

    shared_examples 'build one book then two books' do
      context 'the first build' do
        let(:out) { outputs[0] }
        include_examples 'commits changes'
        it 'does print that it is building the original book' do
          expect(out).to include('Test: Building master...')
        end
        it "doesn't print that it is building the new book" do
          # The new book doesn't exist at this point in the test
          expect(out).not_to include('Test2: Building master...')
        end
      end
      page_context 'html/test/current/chapter.html'
    end

    shared_examples 'second build is noop' do
      context 'the second build' do
        let(:out) { outputs[1] }
        it "doesn't print that it is building any books" do
          expect(out).not_to include(': Building ')
        end
        it 'prints that it is not pushing anything' do
          expect(out).to include('No changes to push')
        end
      end
    end

    shared_examples 'second build is not a noop' do
      context 'the second build' do
        let(:out) { outputs[1] }
        include_examples 'builds all books'
      end
      page_context 'html/test/current/chapter.html' do
        it 'includes the new text' do
          expect(body).to include(new_text)
        end
      end
    end

    context 'when building one book out of one repo twice' do
      context 'when the second build is a noop' do
        let(:latest_revision) { 'init' }

        context 'because there are no changes to the source repo' do
          build_one_book_out_of_one_repo_twice
          include_examples 'second build is noop'
        end
        context 'even when there are unrelated changes source repo' do
          build_one_book_out_of_one_repo_twice(
            before_second_build: lambda do |src, _config|
              repo = src.repo 'repo'
              repo.write 'garbage', 'junk'
              repo.commit 'adding junk'
            end
          )
          include_examples 'second build is noop'
        end
        context 'when --keep_hash is specified and there are related ' \
                'changes source repo' do
          build_one_book_out_of_one_repo_twice(
            before_second_build: lambda do |src, config|
              repo = src.repo 'repo'
              repo.write 'index.asciidoc', <<~ASCIIDOC
                = Title

                [[chapter]]
                == Chapter
                New text.
              ASCIIDOC
              repo.commit 'changed text'

              config.keep_hash = true
            end
          )
          include_examples 'second build is noop'
        end
        context 'even when there is a target_branch' do
          build_one_book_out_of_one_repo_twice(
            before_first_build: lambda do |_src, config|
              config.target_branch = 'new_target'
            end
          )
          include_examples 'second build is noop'
        end
        context 'even when there is a new target branch' do
          build_one_book_out_of_one_repo_twice(
            before_second_build: lambda do |_src, config|
              config.target_branch = 'new_target'
              config.checkout_branch = 'master'
            end
          )
          include_examples 'second build is noop'
        end
      end
      context "when the second build isn't a noop" do
        context 'because the source repo changes' do
          build_one_book_out_of_one_repo_twice(
            before_second_build: lambda do |src, _config|
              repo = src.repo 'repo'
              repo.write 'index.asciidoc', <<~ASCIIDOC
                = Title

                [[chapter]]
                == Chapter
                New text.
              ASCIIDOC
              repo.commit 'changed text'
            end
          )
          let(:latest_revision) { 'changed text' }
          let(:new_text) { 'New text.' }
          include_examples 'second build is not a noop'
        end
        context 'because the book changes from asciidoc to asciidoctor' do
          build_one_book_out_of_one_repo_twice(
            before_first_build: lambda do |src, _config|
              book = src.book 'Test'
              book.asciidoctor = false
            end,
            before_second_build: lambda do |src, _config|
              book = src.book 'Test'
              book.asciidoctor = true
            end
          )
          let(:latest_revision) { 'init' }
          let(:new_text) { 'Some text.' }
          include_examples 'second build is not a noop'
        end
        context 'because the book changes from asciidoctor to asciidoc' do
          build_one_book_out_of_one_repo_twice(
            before_second_build: lambda do |src, _config|
              book = src.book 'Test'
              book.asciidoctor = false
            end
          )
          let(:latest_revision) { 'init' }
          let(:new_text) { 'Some text.' }
          include_examples 'second build is not a noop'
        end
        context 'because we remove the target_branch' do
          # Removing the target branch causes us to build into the *empty*
          # master branch. Being empty, there aren't any books in it to
          # consider "already built".
          build_one_book_out_of_one_repo_twice(
            before_first_build: lambda do |_src, config|
              config.target_branch = 'new_target'
            end,
            before_second_build: lambda do |_src, config|
              config.target_branch = nil # nil means don't override
            end
          )
          let(:latest_revision) { 'init' }
          let(:new_text) { 'Some text.' }
          include_examples 'second build is not a noop'
        end
        context 'because we remove a branch from the book' do
          build_one_book_out_of_one_repo_twice(
            before_first_build: lambda do |src, _config|
              repo = src.repo 'repo'
              book = src.book 'Test'
              book.branches.push 'foo'
            end,
            before_second_build: lambda do |src, _config|
              book = src.book 'Test'
              book.asciidoctor = true
            end
          )
          let(:latest_revision) { 'init' }
          let(:new_text) { 'Some text.' }
          include_examples 'second build is not a noop'
        end
      end
    end

    context 'when building one book out of one repo and then out of two' do
      context 'when the second build is a noop' do
        let(:latest_revision) { 'init' }
        context 'because it was run with --keep_hash' do
          build_one_book_out_of_one_repo_and_then_out_of_two(
            before_second_build: lambda do |_src, config|
              config.keep_hash = true
            end
          )
          include_examples 'second build is noop'
        end
      end
      context "when the second build isn't a noop" do
        let(:latest_revision) { 'adding junk' }
        context 'because it was run without any special flags' do
          build_one_book_out_of_one_repo_and_then_out_of_two
          let(:new_text) { 'Some text.' }
          include_examples 'second build is not a noop'
        end
      end
    end

    context 'when building one book out of two repos twice' do
      context 'when the second build is a noop' do
        let(:latest_revision) { 'init' }

        context 'because there are no changes to the either repo' do
          build_one_book_out_of_two_repos_twice
          include_examples 'second build is noop'
        end
        context 'because there are unrelated changes to the index repo' do
          build_one_book_out_of_two_repos_twice(
            before_second_build: lambda do |src|
              repo1 = src.repo 'repo1'
              repo1.write 'garbage', 'junk'
              repo1.commit 'adding junk'
            end
          )
          include_examples 'second build is noop'
        end
        context 'because there are unrelated changes to the included repo' do
          build_one_book_out_of_two_repos_twice(
            before_second_build: lambda do |src|
              repo2 = src.repo 'repo2'
              repo2.write 'garbage', 'junk'
              repo2.commit 'adding junk'
            end
          )
          include_examples 'second build is noop'
        end
        context 'because there is an unrelated change in a mapped branch' do
          build_one_book_out_of_two_repos_twice(
            before_first_build: lambda do |src|
              book = src.book 'Test'
              repo2 = src.repo 'repo2'
              book.source repo2, 'included.asciidoc',
                          map_branches: { 'master': 'override' }
              repo2.switch_to_new_branch 'override'
            end,
            before_second_build: lambda do |src|
              repo2 = src.repo 'repo2'
              repo2.write 'garbage', 'junk'
              repo2.commit 'adding junk'
            end
          )
          include_examples 'second build is noop'
        end
      end
      context "when the second build isn't a noop" do
        let(:latest_revision) { 'changed text' }
        let(:new_text) { 'new text' }

        context 'because the index repo changes' do
          build_one_book_out_of_two_repos_twice(
            before_second_build: lambda do |src|
              repo1 = src.repo 'repo1'
              text = repo1.read 'index.asciidoc'
              repo1.write 'index.asciidoc', text + 'new text'
              repo1.commit 'changed text'
            end
          )
          include_examples 'second build is not a noop'
        end
        context 'because the included repo changes' do
          build_one_book_out_of_two_repos_twice(
            before_second_build: lambda do |src|
              repo2 = src.repo 'repo2'
              repo2.write 'included.asciidoc', 'new text'
              repo2.commit 'changed text'
            end
          )
          include_examples 'second build is not a noop'
        end
        context "because a repo's branch mapping changes" do
          build_one_book_out_of_two_repos_twice(
            before_second_build: lambda do |src|
              book = src.book 'Test'
              repo2 = src.repo 'repo2'
              book.source repo2, 'included.asciidoc',
                          map_branches: { 'master': 'override' }
              repo2.switch_to_new_branch 'override'
            end
          )
          # We don't make a new commit so the latest revision is still 'init'
          let(:latest_revision) { 'init' }
          # And the text hasn't changed
          let(:new_text) { 'included text' }
          include_examples 'second build is not a noop'
        end
        context 'because there is a change in a mapped branch' do
          build_one_book_out_of_two_repos_twice(
            before_first_build: lambda do |src|
              book = src.book 'Test'
              repo2 = src.repo 'repo2'
              book.source repo2, 'included.asciidoc',
                          map_branches: { 'master': 'override' }
              repo2.switch_to_new_branch 'override'
            end,
            before_second_build: lambda do |src|
              repo2 = src.repo 'repo2'
              repo2.write 'included.asciidoc', 'new text'
              repo2.commit 'changed text'
            end
          )
          include_examples 'second build is not a noop'
        end
      end
    end

    context 'when building one book and then building two books' do
      context 'without any special flags' do
        build_one_book_then_two_books
        let(:latest_revision) { 'init' }
        context 'the second build' do
          let(:out) { outputs[1] }
          include_examples 'commits changes'
          it "doesn't print that it is building the original book" do
            # The original book hasn't changed so we don't rebuild it
            expect(out).not_to include('Test: Building master...')
          end
          it 'does print that it is building the new book' do
            expect(out).to include('Test2: Building master...')
          end
        end
        page_context 'html/test2/current/chapter.html'
      end
      context 'when --keep_hash is specified' do
        build_one_book_then_two_books(
          before_second_build: lambda do |_src, config|
            config.keep_hash = true
          end
        )
        let(:latest_revision) { 'init' }
        context 'the second build' do
          let(:out) { outputs[1] }
          it "doesn't print that it is building the original book" do
            # The original book hasn't changed so we don't rebuild it
            expect(out).not_to include('Test: Building master...')
          end
          it "doesn't print that it is building the new book" do
            expect(out).not_to include('Test2: Building master...')
          end
          it 'does print that it is pushing changes' do
            # This is because the TOC includes the new book. That isn't great
            # but it is fine.
            expect(out).to include('Pushing changes')
          end
        end
      end
    end
  end
end
