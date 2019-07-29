# frozen_string_literal: true

require 'net/http'

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
  context 'for a single book built by a single repo with two sources' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', <<~ASCIIDOC
        Some text.

        image::resources/cat.jpg[A cat]
      ASCIIDOC
      root = File.expand_path '../../', __dir__
      repo.cp "#{root}/resources/cat.jpg", 'resources/cat.jpg'
      repo.commit 'add cat image'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      book.source repo, 'resources'
    end
    let(:latest_revision) { 'add cat image' }
    include_examples 'book basics', 'Test', 'test'
    page_context "the current version's chapter page",
                 'html/test/current/chapter.html' do
      it 'has a link to the image' do
        expect(body).to include(<<~HTML.strip)
          <img src="resources/cat.jpg" alt="A cat" />
        HTML
      end
    end
    file_context 'html/test/current/resources/cat.jpg'
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

  context 'when a book overrides edit_me' do
    def self.index
      <<~ASCIIDOC
        = Test

        :edit_url: overridden
        [[chapter]]
        == Chapter

        Words.
      ASCIIDOC
    end

    def self.override_edit_me(respect)
      convert_all_before_context target_branch: 'new_branch' do |src|
        repo = src.repo_with_file 'repo', 'index.asciidoc', index
        book = src.book 'Test'
        book.respect_edit_url_overrides = true if respect
        book.source repo, 'index.asciidoc'
      end
    end
    let(:edit_me) do
      <<~HTML.lines.map { |l| ' ' + l.strip }.join.strip
        <a href="#{edit_url}"
           class="edit_me"
           title="Edit this page on GitHub"
           rel="nofollow">edit</a>
      HTML
    end
    let(:latest_revision) { 'init' }
    context "when respect_edit_url_overrides isn't specified" do
      override_edit_me false
      let(:repo) { @src.repo 'repo' }
      let(:edit_url) { "#{repo.root}/edit/master/index.asciidoc" }
      page_context 'the book index', 'html/test/master/chapter.html' do
        it 'contains the standard edit_me link' do
          expect(body).to include(edit_me)
        end
      end
    end
    context 'when respect_edit_url_overrides is specified' do
      override_edit_me true
      let(:edit_url) { 'overridden' }
      page_context 'the book index', 'html/test/master/chapter.html' do
        it 'contains the overridden edit_me link' do
          expect(body).to include(edit_me)
        end
      end
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

  context 'for a book with console alternatives' do
    def self.index
      <<~ASCIIDOC
        [source,console]
        ----------------------------------
        GET /_search
        {
            "query": "foo bar" <1>
        }
        ----------------------------------
        <1> Example

        [source,console]
        ----------------------------------
        GET /_search
        {
            "query": "missing"
        }
        ----------------------------------
      ASCIIDOC
    end

    def self.examples_dir
      "#{__dir__}/../readme_examples/"
    end

    def self.setup_example(repo, lang)
      repo.cp(
        "#{examples_dir}/#{lang}/8a7e0a79b1743d5fd94d79a7106ee930.adoc",
        'examples/8a7e0a79b1743d5fd94d79a7106ee930.adoc'
      )
      repo.commit 'add example'
    end

    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', index

      js_repo = src.repo 'js'
      setup_example js_repo, 'js'

      csharp_repo = src.repo 'csharp'
      csharp_repo.write 'dummy', 'dummy'
      csharp_repo.commit 'init'
      csharp_repo.switch_to_new_branch 'mapped'
      setup_example csharp_repo, 'csharp'

      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      book.source(
        js_repo,
        'examples',
        alternatives: { source_lang: 'console', alternative_lang: 'js' }
      )
      book.source(
        csharp_repo,
        'examples',
        map_branches: { 'master': 'mapped' },
        alternatives: { source_lang: 'console', alternative_lang: 'csharp' }
      )
    end
    let(:latest_revision) { 'init' }
    page_context 'html/test/master/chapter.html' do
      it 'contains the default example' do
        expect(body).to include(<<~HTML.strip)
          <pre class="default programlisting prettyprint lang-console">GET /_search
          {
              "query": "foo bar" <a id="CO1-1"></a><span><img src="images/icons/callouts/1.png" alt="" /></span>
          }</pre></div>
        HTML
      end
      it 'contains the js example' do
        expect(body).to include(<<~HTML.strip)
          <pre class="alternative programlisting prettyprint lang-js">const result = await client.search({
            body: { query: 'foo bar' }
          })</pre></div>
        HTML
      end
      it 'contains the csharp example' do
        expect(body).to include(<<~HTML.strip)
          <pre class="alternative programlisting prettyprint lang-csharp">var searchResponse = _client.Search&lt;Project&gt;(s =&gt; s
              .Query(q =&gt; q
                  .QueryString(m =&gt; m
                      .Query("foo bar")
                  )
              )
          );</pre></div>
        HTML
      end
      file_context 'html/test/master/missing_alternatives/console/js' do
        it 'contains only the missing example' do
          expect(contents).to eq(<<~LOG)
            * d21765565081685a36dfc4af89e7cece.adoc: index.asciidoc: line 15
          LOG
        end
      end
      file_context 'html/test/master/missing_alternatives/console/csharp' do
        it 'contains only the missing example' do
          expect(contents).to eq(<<~LOG)
            * d21765565081685a36dfc4af89e7cece.adoc: index.asciidoc: line 15
          LOG
        end
      end
    end
  end

  context 'when run with --open' do
    include_context 'source and dest'
    before(:context) do
      repo = @src.repo_with_index 'repo', 'Words'
      book = @src.book 'Test'
      book.source repo, 'index.asciidoc'
      @opened_docs = @dest.prepare_convert_all(@src.conf).open
    end
    after(:context) do
      @opened_docs.exit
    end

    let(:root) { 'http://localhost:8000/guide/' }
    let(:index) { Net::HTTP.get_response(URI(root)) }
    let(:legacy_redirect) do
      Net::HTTP.get_response(URI("#{root}reference/setup/"))
    end

    it 'serves the book' do
      expect(index).to serve(doc_body(include(<<~HTML.strip)))
        <a class="ulink" href="test/current/index.html" target="_top">Test
      HTML
    end
    it 'serves a legacy redirect' do
      expect(legacy_redirect.code).to eq('301')
      expect(legacy_redirect['location']).to eq(
        "#{root}en/elasticsearch/reference/current/setup.html"
      )
    end
  end

  context 'when run with --announce_preview' do
    target_branch = 'foo_1'
    preview_location = "http://#{target_branch}.docs-preview.app.elstc.co/guide"
    convert_before do |src, dest|
      repo = src.repo_with_index 'repo', 'Some text.'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      dest.prepare_convert_all(src.conf)
          .target_branch(target_branch)
          .announce_preview(preview_location)
          .convert
    end
    it 'logs the location of the preview' do
      expect(outputs[0]).to include(
        "A preview will soon be available at #{preview_location}"
      )
    end
  end

  context "when the index for the book isn't in the repo" do
    convert_before do |src, dest|
      repo = src.repo_with_index 'src', 'words'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      book.index = 'not_index.asciidoc'
      dest.prepare_convert_all(src.conf).convert(expect_failure: true)
    end
    it 'fails with an appropriate error status' do
      expect(statuses[0]).to eq(2)
    end
    it 'logs the missing file' do
      expect(outputs[0]).to match(%r{
        Can't\ find\ index\ \[.+/src/not_index.asciidoc\]
      }x)
    end
  end
end
