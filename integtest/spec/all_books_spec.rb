# frozen_string_literal: true

RSpec.describe 'building all books' do
  shared_examples 'book basics' do |title, prefix|
    context "for the #{title} book" do
      page_context 'the book index', "html/#{prefix}/index.html" do
        it 'contains a redirect to the only version of the book' do
          expect(body).to include(
            '<meta http-equiv="refresh" content="0; url=current/index.html">'
          )
        end
      end
      page_context "the current version's index",
                   "html/#{prefix}/current/index.html" do
        it 'have the right title' do
          expect(title).to eq(title)
        end
        it 'contains a table of contents' do
          expect(body).to include('<div class="toc">')
        end
      end
    end
  end
  context 'for a single book built by a single repo' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', 'Some text.'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
    end
    let(:latest_revision) { 'init' }
    include_examples 'book basics', 'Test', 'test'
  end
  context 'for a single book built by two repos' do
    def self.single_book_built_by_two_repos
      convert_all_before_context do |src|
        src.simple_include
        yield src if block_given?
      end
      include_context 'single book built by two repos'
    end
    shared_context 'single book built by two repos' do
      let(:latest_revision) { 'init' }
      include_examples 'book basics', 'Test', 'test'
      page_context 'html/test/current/chapter.html' do
        it 'contains the text from the index' do
          expect(body).to include('Include between here')
        end
      end
    end
    context "when the repos don't have any special configuration" do
      single_book_built_by_two_repos
      page_context 'html/test/current/chapter.html' do
        it 'contains the included text' do
          expect(body).to include('included text')
        end
      end
    end
    context 'when one of the repos has a branch map' do
      single_book_built_by_two_repos do |src|
        repo2 = src.repo 'repo2'
        repo2.switch_to_new_branch 'override'
        repo2.write 'included.asciidoc', <<~ASCIIDOC
          correct text to include
        ASCIIDOC
        repo2.commit 'on override branch'
        book = src.book 'Test'
        book.source repo2, 'included.asciidoc',
                    map_branches: { 'master': 'override' }
      end
      page_context 'html/test/current/chapter.html' do
        it 'contains the included text' do
          expect(body).to include('correct text to include')
        end
      end
    end
  end
  context 'for two books built by a single repo' do
    convert_all_before_context do |src|
      repo = src.repo 'repo'
      repo.write 'first/index.asciidoc', <<~ASCIIDOC
        = Title

        == Chapter

        Some text.
      ASCIIDOC
      repo.write 'second/index.asciidoc', <<~ASCIIDOC
        = Title

        == Chapter

        Some text.
      ASCIIDOC
      repo.commit 'init'
      book1 = src.book 'First'
      book1.index = 'first/index.asciidoc'
      book1.source repo, 'first'
      book2 = src.book 'Second'
      book2.index = 'second/index.asciidoc'
      book2.source repo, 'second'
    end
    let(:latest_revision) { 'init' }
    include_examples 'book basics', 'First', 'first'
    include_examples 'book basics', 'Second', 'second'
  end
  context 'for a relative config file' do
    convert_all_before_context relative_conf: true do |src|
      repo = src.repo_with_index 'repo', 'Some text.'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
    end
    let(:latest_revision) { 'init' }
    include_examples 'book basics', 'Test', 'test'
  end
  context 'when target_branch is specified' do
    convert_all_before_context target_branch: 'new_branch' do |src|
      repo = src.repo_with_index 'repo', 'Some text.'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
    end
    let(:latest_revision) { 'init' }
    include_examples 'book basics', 'Test', 'test'
    it 'prints that it is forking the new branch from master' do
      expect(out).to include('target_repo: Forking <new_branch> from master')
    end
  end
  context 'when one source is private' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', <<~ASCIIDOC
        Words

        include::../private_repo/foo.asciidoc[]
      ASCIIDOC
      private_repo = src.repo 'private_repo'
      private_repo.write 'foo.asciidoc', <<~ASCIIDOC
        [[foo]]
        == Foo

        Words
      ASCIIDOC
      private_repo.commit 'build foo'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      book.source private_repo, 'foo.asciidoc', is_private: true
    end
    let(:latest_revision) { 'init' }
    page_context 'html/test/current/chapter.html' do
      it 'does contain an edit link because it is from a public source' do
        expect(body).to include(%(title="Edit this page on GitHub"))
      end
    end

    page_context 'html/test/current/foo.html' do
      it "doesn't contain an edit link because it is from a private source" do
        expect(body).not_to include(%(title="Edit this page on GitHub"))
      end
    end
  end
end
