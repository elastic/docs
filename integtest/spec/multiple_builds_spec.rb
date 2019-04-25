# frozen_string_literal: true

RSpec.describe 'building all books more than once' do
  def self.setup_basic_book(src)
    src.repo('repo').tap do |repo|
      repo.write 'index.asciidoc', <<~ASCIIDOC
        = Title

        [[chapter]]
        == Chapter
        Some text.
      ASCIIDOC
      repo.init
      src.book('Test', 'test').source(repo, 'index.asciidoc')
    end
  end

  def self.build_one_book_twice
    convert_before do |src, dest|
      repo = setup_basic_book src

      # Convert the first time. This should build the docs.
      dest.convert_all src.conf

      # Let the block customize this.
      yield repo

      # Convert the second time.
      dest.convert_all src.conf

      # Checkout the files so we can assert about them.
      dest.checkout_conversion
    end
    include_context 'build one book twice'
  end
  shared_context 'build one book twice' do
    context 'the first build' do
      let(:out) { outputs[0] }
      include_examples 'builds all books'
    end
    include_examples 'convert all basics'
  end

  context 'when building one book out of one repo twice' do
    context 'when the second build is a noop' do
      let(:expected_revision) { 'init' }
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

      context 'because there are no changes to the source repo' do
        build_one_book_twice {}
        include_examples 'second build is noop'
      end

      context 'because there are unrelated changes source repo' do
        build_one_book_twice do |repo|
          repo.write 'garbage', 'junk'
          repo.commit 'adding junk'
        end
        include_examples 'second build is noop'
      end
    end
    context 'when the second build changes the book' do
      build_one_book_twice do |repo|
        repo.write 'index.asciidoc', <<~ASCIIDOC
          = Title

          [[chapter]]
          == Chapter
          New text.
        ASCIIDOC
        repo.commit 'changed text'
      end
      let(:expected_revision) { 'changed text' }
      context 'the second build' do
        let(:out) { outputs[1] }
        include_examples 'builds all books'
      end
    end
  end
end
