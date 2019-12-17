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
    convert_all_before_context(init_from_shell: false) do |src|
      repo = src.repo_with_index 'repo', 'Some text.'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
    end
    include_examples 'book basics', 'Test', 'test'
    file_context 'raw/test/master/index.html' do
      it "doesn't contain the noindex flag" do
        expect(contents).not_to include(<<~HTML.strip)
          <meta name="robots" content="noindex,nofollow" />
        HTML
      end
    end

    def self.has_license(name, heading)
      it "has license for #{name}" do
        expect(contents).to include(<<~TXT)
          /* #{name}
           * #{heading}
        TXT
      end
    end
    file_context 'html/static/docs.js' do
      has_license 'code-prettify', 'The Apache 2.0 License'
      has_license "code-prettify's lang-sql", 'The Apache 2.0 License'
      has_license "code-prettify's lang-yaml", 'The Apache 2.0 License'
      has_license 'js-cookie', 'The MIT License (MIT)'
      has_license 'linkstate', 'The MIT License (MIT)'
      has_license 'loose-envify', 'The MIT License (MIT)'
      has_license 'preact', 'The MIT License (MIT)'
      has_license 'preact-context', 'The Apache 2.0 License'
      has_license 'preact-redux', 'The MIT License (MIT)'
      has_license 'ramda', 'The MIT License (MIT)'
      has_license 'redux', 'The MIT License (MIT)'
      has_license 'redux-thunk', 'The MIT License (MIT)'
      has_license 'symbol-observable', 'The MIT License (MIT)'
    end
    file_context 'html/static/styles.css' do
      has_license 'Bootstrap', 'The MIT License (MIT)'
      has_license 'Inter', 'SIL OPEN FONT LICENSE'
      has_license 'Noto Sans Japanese', 'SIL OPEN FONT LICENSE'
    end
    file_context 'html/static/Inter-Medium.5d08e0ba.woff2'
    file_context 'html/static/NotoSansJP-Black.df80409c.woff2'
    file_context 'html/sitemap.xml' do
      it 'has an entry for the chapter' do
        expect(contents).to include(<<~XML)
          <loc>https://www.elastic.co/guide/test/current/chapter.html</loc>
        XML
      end
    end
  end
  context 'for a single book with two chapters' do
    convert_all_before_context do |src|
      repo = src.repo 'repo'
      repo.write 'index.asciidoc', <<~ASCIIDOC
        = Title

        [[chapter1]]
        == Chapter 1

        Some text.

        [[chapter2]]
        == Chapter 2

        Some more text.
      ASCIIDOC
      repo.commit 'init'

      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
    end
    include_examples 'book basics', 'Test', 'test'
    file_context 'html/sitemap.xml' do
      let(:chapter1_index) { contents.index 'chapter1.html' }
      let(:chapter2_index) { contents.index 'chapter2.html' }
      it 'the entry for chapter 1 is before the entry for chapter 2' do
        # Sorting the file is important to prevent "jumping arround" when we
        # rebuild it.
        expect(chapter1_index).to be < chapter2_index
      end
    end
  end
  context 'for a single book built by a single repo with two sources' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', <<~ASCIIDOC
        Some text.

        image::resources/readme/cat.jpg[A cat]
      ASCIIDOC
      root = File.expand_path '../../', __dir__
      repo.cp "#{root}/resources/readme/cat.jpg", 'resources/readme/cat.jpg'
      repo.commit 'add cat image'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      book.source repo, 'resources'
    end
    include_examples 'book basics', 'Test', 'test'
    page_context "the current version's raw chapter page",
                 'raw/test/current/chapter.html' do
      it 'has a link to the image' do
        expect(body).to include(<<~HTML.strip)
          <img src="resources/readme/cat.jpg" alt="A cat" />
        HTML
      end
    end
    page_context "the current version's chapter page",
                 'html/test/current/chapter.html' do
      it 'has a link to the image' do
        expect(body).to include(<<~HTML.strip)
          <img src="resources/readme/cat.jpg" alt="A cat" />
        HTML
      end
    end
    page_context "the master version's chapter page",
                 'html/test/master/chapter.html' do
      it 'has a link to the image' do
        expect(body).to include(<<~HTML.strip)
          <img src="resources/readme/cat.jpg" alt="A cat" />
        HTML
      end
    end
    file_context "the master version's raw chapter page",
                 'raw/test/master/chapter.html' do
      it 'has a link to the image' do
        expect(contents).to include(<<~HTML.strip)
          <img src="resources/readme/cat.jpg" alt="A cat" />
        HTML
      end
    end
    file_context 'html/test/current/resources/readme/cat.jpg'
    file_context 'raw/test/current/resources/readme/cat.jpg'
    file_context 'html/test/master/resources/readme/cat.jpg'
    file_context 'raw/test/master/resources/readme/cat.jpg'
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
    include_examples 'book basics', 'First', 'first'
    include_examples 'book basics', 'Second', 'second'
  end
  context 'for a relative config file' do
    convert_all_before_context relative_conf: true do |src|
      repo = src.repo_with_index 'repo', 'Some text.'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
    end
    include_examples 'book basics', 'Test', 'test'
  end
  context 'when target_branch is specified' do
    convert_all_before_context target_branch: 'new_branch' do |src|
      repo = src.repo_with_index 'repo', 'Some text.'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
    end
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
    context "when respect_edit_url_overrides isn't specified" do
      override_edit_me false
      let(:repo) { @src.repo 'repo' }
      let(:edit_url) { "#{repo.root}/edit/master/index.asciidoc" }
      page_context 'html/test/master/chapter.html' do
        it 'contains the standard edit_me link' do
          expect(body).to include(edit_me)
        end
      end
    end
    context 'when respect_edit_url_overrides is specified' do
      override_edit_me true
      let(:edit_url) { 'overridden' }
      page_context 'html/test/master/chapter.html' do
        it 'contains the overridden edit_me link' do
          expect(body).to include(edit_me)
        end
      end
    end
  end

  context 'when there is a link to elastic.co' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', <<~ASCIIDOC
        https://www.elastic.co/cloud/[link]
      ASCIIDOC
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
    end
    page_context 'raw/test/master/chapter.html' do
      it 'contains a relative link to www.elatic.co' do
        expect(body).to include(<<~HTML.strip)
          <a class="ulink" href="/cloud/" target="_top">link</a>
        HTML
      end
    end
  end

  context 'for a book with many branches' do
    shared_examples 'many branches' do |direct_html|
      convert_all_before_context do |src|
        repo = src.repo_with_index 'repo', <<~ASCIIDOC
          The branch is {source_branch}.
        ASCIIDOC
        repo.switch_to_new_branch 'foo'
        repo.switch_to_new_branch '7.x'
        repo.switch_to_new_branch '1.2'

        book = src.book 'Test'
        book.source repo, 'index.asciidoc'
        book.direct_html = true if direct_html
        book.branches.push 'foo', '7.x', '1.2'
      end
      shared_examples 'contains branch' do |branch|
        it 'uses {source_branch} to resolve the branch name' do
          expect(body).to include("The branch is #{branch}.")
        end
      end
      page_context 'html/test/master/chapter.html' do
        include_examples 'contains branch', 'master'
      end
      page_context 'html/test/foo/chapter.html' do
        include_examples 'contains branch', 'foo'
      end
      page_context 'html/test/7.x/chapter.html' do
        include_examples 'contains branch', '7.x'
      end
      page_context 'html/test/1.2/chapter.html' do
        include_examples 'contains branch', '1.2'
      end
    end
    context 'when built with docbook' do
      include_examples 'many branches', false
    end
    context 'when built with direct_html' do
      include_examples 'many branches', true
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
    def self.examples_dir
      "#{__dir__}/../readme_examples/"
    end

    def self.setup_example(repo, lang, hash)
      repo.cp(
        "#{examples_dir}/#{lang}/#{hash}.adoc",
        "examples/#{hash}.adoc"
      )
      repo.commit 'add example'
    end

    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', ConsoleExamples::README_LIKE

      js_repo = src.repo 'js'
      setup_example js_repo, 'js', '8a7e0a79b1743d5fd94d79a7106ee930'
      setup_example js_repo, 'js', '9fa2da152878d1d5933d483a3c2af35e'

      csharp_repo = src.repo 'csharp'
      csharp_repo.write 'dummy', 'dummy'
      csharp_repo.commit 'init'
      csharp_repo.switch_to_new_branch 'mapped'
      setup_example csharp_repo, 'csharp', '8a7e0a79b1743d5fd94d79a7106ee930'

      java_repo = src.repo 'java'
      java_repo.write 'examples/dummy', 'dummy'
      java_repo.commit 'init'

      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      js_alt = { source_lang: 'console', alternative_lang: 'js' }
      book.source js_repo, 'examples', alternatives: js_alt
      book.source(
        csharp_repo,
        'examples',
        map_branches: { 'master': 'mapped' },
        alternatives: { source_lang: 'console', alternative_lang: 'csharp' }
      )
      java_alts = { source_lang: 'console', alternative_lang: 'java' }
      book.source(java_repo, 'examples', alternatives: java_alts)
    end
    let(:direct_html) { false }
    include_examples 'README-like console alternatives',
                     'raw/test/master', 'html/test/master'
  end

  context 'when run with --open' do
    repo_root = File.expand_path '../../', __dir__
    readme_resources = "#{repo_root}/resources/readme"
    include_context 'source and dest'

    before(:context) do
      repo = @src.repo_with_index 'repo', <<~ASCIIDOC
        Some text.

        image::resources/readme/cat.jpg[A cat]
        image::resources/readme/example.svg[An example svg]
      ASCIIDOC
      repo.cp "#{readme_resources}/cat.jpg", 'resources/readme/cat.jpg'
      repo.cp "#{readme_resources}/example.svg", 'resources/readme/example.svg'
      repo.commit 'add images'

      book = @src.book 'Test'
      book.source repo, 'index.asciidoc'
      book.source repo, 'resources'
      @opened_docs = @dest.prepare_convert_all(@src.conf).open
    end
    after(:context) do
      @opened_docs&.exit
    end

    let(:root) { 'http://localhost:8000/guide' }
    let(:book_root) { "#{root}/test/current" }
    let(:guide_index) { Net::HTTP.get_response(URI("#{root}/")) }
    let(:legacy_redirect) do
      Net::HTTP.get_response(URI("#{root}/reference/setup/"))
    end
    let(:cat_image) do
      Net::HTTP.get_response(URI("#{book_root}/resources/readme/cat.jpg"))
    end
    let(:svg_image) do
      Net::HTTP.get_response(URI("#{book_root}/resources/readme/example.svg"))
    end

    include_examples 'the root'
    include_examples 'the favicon'
    it 'serves the guide index' do
      expect(guide_index).to serve(doc_body(include(<<~HTML.strip)))
        <a href="test/current/index.html" class="ulink" target="_top">Test
      HTML
    end
    it 'serves a legacy redirect' do
      expect(legacy_redirect).to redirect_to(
        eq(
          "#{root}/en/elasticsearch/reference/current/setup.html"
        )
      )
    end
    context 'for a JPG' do
      it 'serves the right bytes' do
        bytes = File.open("#{readme_resources}/cat.jpg", 'rb', &:read)
        expect(cat_image).to serve(eq(bytes))
      end
      it 'serves the right Content-Type' do
        expect(cat_image['Content-Type']).to eq('image/jpeg')
      end
    end
    context 'for an SVG' do
      it 'serves the right bytes' do
        bytes = File.open("#{readme_resources}/example.svg", 'rb', &:read)
        expect(svg_image).to serve(eq(bytes))
      end
      it 'serves the right Content-Type' do
        expect(svg_image['Content-Type']).to eq('image/svg+xml')
      end
    end
  end

  context 'when the config has toc_extra' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', 'words'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      src.write 'toc_extra.html', '<p>extra html</p>'
      book.toc_extra = 'toc_extra.html'
      src.toc_extra = 'toc_extra.html'
    end
    file_context 'the toc', 'raw/index.html' do
      it 'includes the extra html' do
        expect(contents).to include(<<~HTML)
          <div id="extra">
          <p>extra html</p>
          </div>
        HTML
      end
    end
  end
  context 'when a book has toc_extra' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', 'words'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      src.write 'toc_extra.html', '<p>extra html</p>'
      book.toc_extra = 'toc_extra.html'
      # Add a second branch to the book so it gets "versions" table of contents
      repo.switch_to_new_branch 'other'
      book.branches << 'other'
    end
    file_context 'the toc', 'raw/test/index.html' do
      it 'includes the extra html' do
        expect(contents).to include(<<~HTML)
          <div id="extra">
          <p>extra html</p>
          </div>
        HTML
      end
    end
  end

  context 'when a book contains migration warnings' do
    shared_context 'convert with migration warnings' do |suppress|
      convert_before do |src, dest|
        repo = src.repo_with_index 'repo', <<~ASCIIDOC
          --------
          CODE HERE
          ----
        ASCIIDOC
        book = src.book 'Test'
        book.source repo, 'index.asciidoc'
        book.suppress_migration_warnings = suppress
        dest.prepare_convert_all(src.conf).convert(expect_failure: !suppress)
        dest.checkout_conversion if suppress
      end
    end
    context 'and they are not suppressed' do
      include_context 'convert with migration warnings', false
      it 'fails with an appropriate error status' do
        expect(statuses[0]).to eq(2)
      end
      it 'complains about the MIGRATION warning' do
        expect(outputs[0]).to include(<<~LOG)
          asciidoctor: WARNING: index.asciidoc: line 7: MIGRATION: code block end doesn't match start
        LOG
      end
    end
    context 'and they are suppressed' do
      include_context 'convert with migration warnings', true
      it "doesn't complain about the MIGRATION warning" do
        expect(outputs[0]).not_to include(<<~LOG)
          asciidoctor: WARNING: index.asciidoc: line 7: MIGRATION: code block end doesn't match start
        LOG
      end
      file_context 'raw/test/master/chapter.html' do
        it 'contains the snippet' do
          expect(contents).to include('CODE HERE')
        end
      end
    end
  end
  context 'when the book is configured with noindex' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', 'test'

      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      book.noindex = true
    end
    file_context 'raw/test/master/index.html' do
      it 'contains the noindex flag' do
        expect(contents).to include(<<~HTML.strip)
          <meta name="robots" content="noindex,nofollow" />
        HTML
      end
    end
  end
  context 'when the book has "live" branches' do
    convert_all_before_context do |src|
      repo = src.repo_with_index 'repo', 'test'
      repo.switch_to_new_branch 'nonlive'

      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      book.branches << 'nonlive'
      book.live_branches = ['master']
    end
    let(:repo) { @src.repo 'repo' }
    page_context 'the live branch', 'html/test/master/index.html' do
      it "doesn't contain the noindex flag" do
        expect(contents).not_to include(<<~HTML.strip)
          <meta name="robots" content="noindex,nofollow" />
        HTML
      end
      context 'the live versions drop down' do
        it 'contains only the live branch' do
          expect(body).to include(<<~HTML.strip)
            <select id="live_versions"><option value="master" selected>master (current)</option><option value="other">other versions</option></select>
          HTML
        end
      end
      context 'the other versions drop down' do
        it 'contains all branches' do
          expect(body).to include(<<~HTML.strip)
            <span id="other_versions">other versions: <select><option value="master" selected>master (current)</option><option value="nonlive">nonlive</option></select>
          HTML
        end
      end
    end
    page_context "the live branch's chapter", 'html/test/master/chapter.html' do
      let(:edit_url) { "#{repo.root}/edit/master/index.asciidoc" }
      it 'contains an edit_me link' do
        expect(body).to include <<~HTML.strip
          <a href="#{edit_url}" class="edit_me" title="Edit this page on GitHub" rel="nofollow">edit</a>
        HTML
      end
    end
    page_context "the dead branch's index", 'html/test/nonlive/index.html' do
      it 'contains the noindex flag' do
        expect(contents).to include(<<~HTML.strip)
          <meta name="robots" content="noindex,nofollow" />
        HTML
      end
      context 'the live versions drop down' do
        it 'contains the deprecated branch' do
          expect(body).to include(<<~HTML.strip)
            <select id="live_versions"><option value="master">master (current)</option><option value="nonlive" selected>nonlive</option></select>
          HTML
        end
      end
      it "it doesn't contain the other versions drop down" do
        # *because* there aren't any versions filtered from the list
        expect(body).not_to include 'id="other_versions"'
      end
    end
    page_context "the dead branch's chapter",
                 'html/test/nonlive/chapter.html' do
      let(:edit_url) { "#{repo.root}/edit/master/index.asciidoc" }
      it "doesn't contain an edit_me link" do
        expect(body).not_to include('class="edit_me"')
      end
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

  context 'when there is a NODE_NAME in the environment' do
    convert_before do |src, dest|
      repo = src.repo_with_index 'repo', 'Some text.'
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      dest.prepare_convert_all(src.conf)
          .node_name('my-node-name')
          .convert
    end
    let(:commit_info) { @dest.commit_info }
    it 'adds the NODE_NAME to the commit message' do
      expect(commit_info).to include('my-node-name')
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
  context 'when asciidoctor fails' do
    def self.setup
      convert_before do |src, dest|
        repo = src.repo_with_index 'src', 'include::missing.adoc[]'
        yield repo if block_given?
        book = src.book 'Test'
        book.source repo, 'index.asciidoc'
        dest.prepare_convert_all(src.conf).convert(expect_failure: true)
      end
    end
    shared_examples 'error logging' do
      it 'fails with an appropriate error status' do
        expect(statuses[0]).to eq(2)
      end
      it 'logs the init' do
        expect(outputs[0]).to match(/init \(.+\) <Test>/)
      end
      it 'logs the failure from asciidoc' do
        expect(outputs[0]).to match(/
          ERROR:\ index\.asciidoc:\ line\ \d+:
            \ include\ file\ not\ found:\ .+missing.adoc
        /x)
      end
    end
    context "when the last commit doesn't have utf8 characters" do
      setup
      include_examples 'error logging'
    end
    context 'when the last commit has utf8 characters' do
      setup do |repo|
        repo.append 'index.asciidoc', <<~ASCIIDOC
          words
        ASCIIDOC
        repo.commit 'utf8: á'
      end
      include_examples 'error logging'
      it 'logs the utf8 line' do
        expect(outputs[0]).to match(/utf8: á \(.+\) <Test>/)
      end
    end
  end
end
