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
      repo = src.repo 'repo'
      repo.write 'index.asciidoc', <<~ASCIIDOC
        = Title

        == Chapter

        Some text.
      ASCIIDOC
      book = src.book 'Test', 'test'
      book.source repo, 'index.asciidoc'
    end
    include_examples 'book basics', 'Test', 'test'
  end
  context 'for a single book built by two repos' do
    convert_all_before_context do |src|
      repo1 = src.repo 'repo1'
      repo1.write 'index.asciidoc', <<~ASCIIDOC
        = Title

        [[chapter]]
        == Chapter

        Include between here
        include::../repo2/included.asciidoc[]
        and here.
      ASCIIDOC
      repo2 = src.repo 'repo2'
      repo2.write 'included.asciidoc', <<~ASCIIDOC
        included text
      ASCIIDOC
      book = src.book 'Test', 'test'
      book.source repo1, 'index.asciidoc'
      book.source repo2, 'included.asciidoc'
    end
    include_examples 'book basics', 'Test', 'test'
    page_context 'html/test/current/chapter.html' do
      it 'contains the text from the index' do
        expect(body).to include('Include between here')
      end
      it 'contains the included text' do
        expect(body).to include('included text')
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
      book1 = src.book 'First', 'first'
      book1.index = 'first/index.asciidoc'
      book1.source repo, 'first'
      book2 = src.book 'Second', 'second'
      book2.index = 'second/index.asciidoc'
      book2.source repo, 'second'
    end
    include_examples 'book basics', 'First', 'first'
    include_examples 'book basics', 'Second', 'second'
  end
end
