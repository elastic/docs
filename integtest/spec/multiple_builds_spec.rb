# frozen_string_literal: true

##
# Assertions about when books are rebuilt based on changes in source
# repositories or the book's configuration.
# TODO: rename this to be more consistent with it just being about detecting
#       when the source changes
RSpec.describe 'building all books more than once' do
  def self.build_twice(
      before_first_build:,
      before_second_build: ->(src) {}
    )
    convert_before do |src, dest|
      # Allow the caller to customize the source.
      before_first_build.call(src)

      # Convert the first time. This should build the docs.
      dest.convert_all src.conf

      # Take some action between the builds.
      before_second_build.call(src)

      # Convert the second time.
      dest.convert_all src.conf

      # Checkout the files so we can assert about them.
      dest.checkout_conversion
    end
    include_context 'build one book twice'
  end

  def self.build_one_book_out_of_one_repo_twice(
      before_first_build: ->(src) {},
      before_second_build: ->(src) {}
    )
    build_twice(
      before_first_build: lambda do |src|
        repo = src.repo_with_index 'repo', 'Some text.'
        book = src.book 'Test'
        book.source repo, 'index.asciidoc'

        # Allow the caller to customize the source
        before_first_build.call(src)
      end,
      before_second_build: before_second_build
    )
  end

  def self.build_one_book_out_of_two_repos_twice(
      before_first_build: ->(src) {},
      before_second_build: ->(src) {}
    )
    build_twice(
      before_first_build: lambda do |src|
        src.simple_include

        # Allow the caller to customize the source
        before_first_build.call(src)
      end,
      before_second_build: before_second_build
    )
  end

  shared_context 'build one book twice' do
    context 'the first build' do
      let(:out) { outputs[0] }
      include_examples 'builds all books'
    end
    include_examples 'convert all basics'
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

      context 'because there are unrelated changes source repo' do
        build_one_book_out_of_one_repo_twice(
          before_second_build: lambda do |src|
            repo = src.repo 'repo'
            repo.write 'garbage', 'junk'
            repo.commit 'adding junk'
          end
        )
        include_examples 'second build is noop'
      end
    end
    context "when the second build isn't a noop" do
      let(:latest_revision) { 'changed text' }
      let(:new_text) { 'New text.' }

      context 'because the source repo changes' do
        build_one_book_out_of_one_repo_twice(
          before_second_build: lambda do |src|
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
        include_examples 'second build is not a noop'
      end
      context 'because the book changes from asciidoc to asciidoctor' do
        build_one_book_out_of_one_repo_twice(
          before_first_build: lambda do |src|
            book = src.book 'Test'
            book.asciidoctor = false
          end,
          before_second_build: lambda do |src|
            book = src.book 'Test'
            book.asciidoctor = true
          end
        )
        # We didn't change the revision....
        let(:latest_revision) { 'init' }
        # And the text hasn't changed
        let(:new_text) { 'Some text.' }
        include_examples 'second build is not a noop'
      end
      context 'because the book changes from asciidoctor to asciidoc' do
        build_one_book_out_of_one_repo_twice(
          before_second_build: lambda do |src|
            book = src.book 'Test'
            book.asciidoctor = false
          end
        )
        # We didn't change the revision....
        let(:latest_revision) { 'init' }
        # And the text hasn't changed
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
end
