# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'securerandom'

##
# Test for a preview that is usually deployed in Elastic Apps. It previews all
# branches of the `--target_repo`. The test runs everything in the defined
# order because starting the preview is fairly heavy and the preview is
# designed to update itself as its target repo changes so we start it once and
# play with the target repo during the tests.
RSpec.describe 'previewing built docs', order: :defined do
  very_large_text = 'muchtext' * 1024 * 1024 * 5 # 40mb
  repo_root = File.expand_path '../../', __dir__
  readme_resources = "#{repo_root}/resources/readme"

  convert_before do |src, dest|
    repo = src.repo_with_index 'repo', <<~ASCIIDOC
      Some text.

      image::resources/readme/cat.jpg[A cat]
      image::resources/readme/example.svg[An example svg]
      image::resources/very_large.jpg[Not a jpg but very big]
    ASCIIDOC
    repo.cp "#{readme_resources}/cat.jpg", 'resources/readme/cat.jpg'
    repo.cp "#{readme_resources}/example.svg", 'resources/readme/example.svg'
    repo.write 'resources/very_large.jpg', very_large_text
    repo.commit 'add images'
    book = src.book 'Test'
    book.source repo, 'index.asciidoc'
    book.source repo, 'resources'
    dest.convert_all src.conf
  end
  before(:context) do
    @preview = @dest.start_preview
  end
  after(:context) do
    @preview&.exit
  end
  let(:repo) { @dest.bare_repo.sub '.git', '' }
  let(:preview) { @preview }
  let(:logs) { preview.logs }

  # The preview server reads the branch from the `Host` header. It throws out
  # everything after and including the first `.` so you can hit a branch
  # at urls like `http://master.docs-preview.app.elstc.co/`. Also, if it
  # can't find the `.` then it just assumes master.
  let(:host) { "#{branch}.localhost" }

  def wait_for_logs(regexp, timeout: 10)
    preview.wait_for_logs(regexp, timeout)
  rescue Timeout::Error
    expect(preview.logs).to match(regexp)
  end

  def wait_for_access(path)
    wait_for_logs(/^#{watermark} #{host}.+#{path}.+$/)
  end

  def get(watermark, branch, path)
    uri = URI("http://localhost:8000/#{path}")
    req = Net::HTTP::Get.new(uri)
    raise "branches can't contain [.]" if branch.include? '.'

    req['X-Opaque-Id'] = watermark
    req['Host'] = host
    Net::HTTP.start(uri.hostname, uri.port, read_timeout: 20) do |http|
      http.request(req)
    end
  end

  shared_context 'docs for branch' do
    watermark = SecureRandom.uuid
    let(:watermark) { watermark }
    let(:current_url) { 'guide/test/current' }
    let(:liveness) { get watermark, branch, 'liveness' }
    let(:diff) { get watermark, branch, 'diff' }
    let(:robots_txt) { get watermark, branch, 'robots.txt' }
    let(:root) { get watermark, branch, '' }
    let(:guide_root) { get watermark, branch, 'guide/index.html' }
    let(:current_index) { get watermark, branch, "#{current_url}/index.html" }
    let(:current_toc) { get watermark, branch, "#{current_url}/toc.html" }
    let(:cat_image) do
      get watermark, branch, "#{current_url}/resources/readme/cat.jpg"
    end
    let(:svg_image) do
      get watermark, branch, "#{current_url}/resources/readme/example.svg"
    end
    let(:very_large) do
      get watermark, branch, "#{current_url}/resources/very_large.jpg"
    end
    let(:directory) do
      get watermark, branch, 'guide'
    end
    let(:legacy_redirect) do
      get watermark, branch, 'guide/reference/setup/'
    end
    let(:outside_of_guide) do
      get watermark, branch, 'cloud/elasticsearch-service/signup'
    end
  end

  let(:expected_js_state) { {} }
  let(:expected_language) { 'en' }

  it 'logs that the built docs are ready' do
    wait_for_logs(/Built docs are ready/)
  end
  include_examples 'the favicon'

  shared_examples 'serves some docs' do |supports_gapped: true|
    context 'the liveness check' do
      it '200s' do
        expect(liveness).to serve(include("R'lyeh"))
      end
    end
    context 'the root' do
      it 'redirects to the guide root' do
        expect(root).to redirect_to(eq("http://#{host}:8000/guide/index.html"))
      end
      it 'logs the access to the docs root' do
        wait_for_access '/'
        expect(logs).to include(<<~LOGS)
          #{watermark} #{host} GET / HTTP/1.1 301
        LOGS
      end
    end
    context 'the docs root' do
      it 'contains a link to the current index' do
        expect(guide_root).to serve(doc_body(include(<<~HTML.strip)))
          <a class="ulink" href="test/current/index.html" target="_top">Test</a>
        HTML
      end
      it 'logs access to the docs root' do
        wait_for_access '/'
        expect(logs).to include(<<~LOGS)
          #{watermark} #{host} GET /guide/index.html HTTP/1.1 200
        LOGS
      end
      it 'contains the gtag js' do
        expect(guide_root).to serve(include(<<~HTML.strip))
          https://www.googletagmanager.com/gtag/js
        HTML
      end
      it 'logs the access to the guide root' do
        wait_for_access '/guide/index.html'
        expect(logs).to include(<<~LOGS)
          #{watermark} #{host} GET /guide/index.html HTTP/1.1 200
        LOGS
      end
      if supports_gapped
        context 'when air gapped' do
          let(:host) { "gapped_#{branch}.localhost" }
          it "doesn't contain the gtag js" do
            expect(guide_root).not_to serve(include(<<~HTML.strip))
              https://www.googletagmanager.com/gtag/js
            HTML
          end
          it 'logs the access to the air gapped docs root' do
            wait_for_access '/guide/index.html'
            expect(logs).to include(<<~LOGS)
              #{watermark} #{host} GET /guide/index.html HTTP/1.1 200
            LOGS
          end
        end
      end
    end
    context 'the current index' do
      it 'has the correct initial_js_state' do
        expect(current_index).to serve(initial_js_state(eq(expected_js_state)))
      end
      it 'has the correct language' do
        expect(current_index).to serve(include(<<~HTML.strip))
          <section id="guide" lang="#{expected_language}">
        HTML
      end
    end
    context 'the current table of contents' do
      it "isn't templated" do
        expect(current_toc).to serve(start_with('<div class="toc">'))
      end
    end
    it 'serves a "go away" robots.txt' do
      expect(robots_txt).to serve(eq(<<~TXT))
        User-agent: *
        Disallow: /
      TXT
      expect(robots_txt['Content-Type']).to eq('text/plain')
    end
    context 'for a legacy redirect' do
      it 'serves the redirect' do
        expect(legacy_redirect).to redirect_to(
          eq(
            '/guide/en/elasticsearch/reference/current/setup.html'
          )
        )
      end
      it 'logs the access to the legacy redirect' do
        wait_for_access '/guide/reference/setup/'
        expect(logs).to include(<<~LOGS)
          #{watermark} #{host} GET /guide/reference/setup/ HTTP/1.1 301
        LOGS
      end
    end
    context 'for a url outside of the docs' do
      it 'redirects to the public site' do
        expect(outside_of_guide).to redirect_to(
          eq('https://www.elastic.co/cloud/elasticsearch-service/signup'),
          '302'
        )
      end
      it 'logs the access to the url outside of the docs' do
        wait_for_access '/cloud/elasticsearch-service/signup'
        expect(logs).to include(<<~LOGS)
          #{watermark} #{host} GET /cloud/elasticsearch-service/signup HTTP/1.1 302
        LOGS
      end
      if supports_gapped
        context 'when air gapped' do
          let(:host) { "gapped_#{branch}.localhost" }
          it '404s' do
            expect(outside_of_guide.code).to eq('404')
          end
          it 'logs the access to the url outside of the docs' do
            wait_for_access '/cloud/elasticsearch-service/signup'
            expect(logs).to include(<<~LOGS)
              #{watermark} #{host} GET /cloud/elasticsearch-service/signup HTTP/1.1 404
            LOGS
          end
        end
      end
    end
  end
  shared_examples '404s' do
    context 'the liveness check' do
      it '200s' do
        expect(liveness).to serve(include("R'lyeh"))
      end
    end
    it '404s for the docs root' do
      expect(guide_root.code).to eq('404')
    end
    it 'logs the access to the docs root' do
      wait_for_access '/guide/index.html'
      expect(logs).to include(<<~LOGS)
        #{watermark} #{host} GET /guide/index.html HTTP/1.1 404
      LOGS
    end
    it '404s for the diff' do
      expect(diff.code).to eq('404')
    end
    it 'logs the access to the diff' do
      wait_for_access '/diff'
      expect(logs).to include(<<~LOGS)
        #{watermark} #{host} GET /diff HTTP/1.1 404
      LOGS
    end
  end
  shared_examples 'valid diff' do
    it 'has the html5 doctype' do
      expect(diff).to serve(include('<!DOCTYPE html>'))
    end
    it 'has the branch in the title' do
      expect(diff).to serve(include("<title>Diff for #{branch}</title>"))
    end
    it "doesn't contain a link to the sitemap" do
      expect(diff).not_to serve(include('sitemap.xml'))
    end
    it "doesn't contain a link to the revision file" do
      expect(diff).not_to serve(include('revisions.txt'))
    end
    it "doesn't contain a link to the branch tracker file" do
      expect(diff).not_to serve(include('branches.yaml'))
    end
    it "doesn't warn about unprocesed output" do
      expect(diff).not_to serve(include('Unprocessed results from git'))
    end
    it 'logs access to the diff when it is accessed' do
      wait_for_access '/diff'
      expect(logs).to include(<<~LOGS)
        #{watermark} #{host} GET /diff HTTP/1.1 200
      LOGS
    end
  end

  describe 'for the master branch' do
    let(:branch) { 'master' }
    include_context 'docs for branch'
    include_examples 'serves some docs'
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
    it 'serves a very large image' do
      expect(very_large).to serve(eq(very_large_text))
    end
    context 'when you request a directory' do
      it 'redirects to index.html' do
        expect(directory).to redirect_to(eq('/guide/index.html'))
      end
    end
  end
  describe "when the host header doesn't have a `.` " \
           'it serves that master branch' do
    let(:host) { 'localhost' }
    let(:branch) { 'master' }
    # This doesn't support air gapped docs because we can't ask for them without
    # the `.`.
    include_examples 'serves some docs', supports_gapped: false
    include_context 'docs for branch'
    context 'the diff' do
      include_examples 'valid diff'
    end
  end
  describe 'for the test branch' do
    let(:branch) { 'test' }
    include_context 'docs for branch'
    include_examples '404s'
  end

  describe 'when we commit to the test branch of the target repo' do
    before(:context) do
      repo = @src.repo 'repo'
      repo.write 'index.asciidoc', <<~ASCIIDOC
        = Title

        [[moved_chapter]]
        == Chapter
        Some text.
      ASCIIDOC
      repo.commit 'test change for test branch'
      @dest.convert_all @src.conf, target_branch: 'test'
    end
    it 'logs the fetch' do
      wait_for_logs(/\[new branch\]\s+test\s+->\s+test/)
      # The leading space in the second line is important because it causes
      # filebeat to group the two log lines.
      expect(logs).to include("\n" + <<~LOGS)
        From #{repo}
         * [new branch]      test       -> test
      LOGS
    end
    describe 'for the test branch' do
      let(:branch) { 'test' }
      include_context 'docs for branch'
      include_examples 'serves some docs'
      context 'the diff' do
        include_examples 'valid diff'
        it 'contains a link to the index which has changed' do
          expect(diff).to serve(include(<<~HTML))
            +4 -4 <a href="/guide/test/master/index.html">test/master/index.html</a>
          HTML
        end
        it 'contains a link to the moved chapter' do
          expect(diff).to serve(include(<<~HTML))
            +1 -1 <a href="/guide/test/master/moved_chapter.html">test/master/chapter.html -> test/master/moved_chapter.html</a>
          HTML
        end
        it "doesn't have a message saying there aren't any differences" do
          expect(diff).not_to serve(include(<<~HTML))
            <p>There aren't any differences!</p>
          HTML
        end
      end
      shared_examples 'logs the fetch' do
        it 'logs the fetch' do
          wait_for_logs(/#{@before_hash}\.\.#{@after_hash}\s+test\s+->\s+test/)
          # The leading space in the second line is important because it causes
          # filebeat to group the two log lines.
          expect(logs).to include("\n" + <<~LOGS)
            From #{repo}
               #{@before_hash}..#{@after_hash}  test       -> test
          LOGS
        end
      end
      describe 'when we modify the template' do
        before(:context) do
          # This simulates modifying the template in the docs repo and running
          # build_docs --all
          work = @src.repo 'work'
          work.clone_from @dest.bare_repo
          work.switch_to_branch 'test'
          @before_hash = work.short_hash
          old_template = work.read 'template.html'
          work.write 'template.html', old_template + 'trailing garbage'
          work.commit 'add garbage to template'
          work.push_to @dest.bare_repo
          @after_hash = work.short_hash
        end
        include_examples 'logs the fetch'
        it 'is immediately reflected in the root' do
          expect(guide_root).to serve(include(<<~HTML.strip))
            </html>\ntrailing garbage
          HTML
        end
      end
      describe 'for a very very large html page' do
        before(:context) do
          # This simulates adding a very large html page without having to
          # render it through asciidoc and docbook which would be very slow
          work = @src.repo 'work'
          @before_hash = work.short_hash
          work.write 'raw/very_large.html', <<~HTML
            <!DOCTYPE html>
            <html>
              <head><title>very large</title></head>
              <body>#{very_large_text}</body>
            </html>
          HTML
          work.commit 'add huge page'
          work.push_to @dest.bare_repo
          @after_hash = work.short_hash
        end
        let(:very_large_html) do
          get watermark, branch, 'guide/very_large.html'
        end
        include_examples 'logs the fetch'
        it 'serves the very large page without crashing' do
          expect(very_large_html).to serve(include(very_large_text))
        end
        it 'logs the access to the very large page' do
          wait_for_access '/guide/very_large.html'
          expect(logs).to include(<<~LOGS)
            #{watermark} #{host} GET /guide/very_large.html HTTP/1.1 200
          LOGS
        end
      end
      describe 'when we remove the template' do
        before(:context) do
          # This simulates what preview branches looked like before committing
          # the template.
          work = @src.repo 'work'
          @before_hash = work.short_hash
          work.delete 'template.html'
          work.commit 'remove template'
          work.push_to @dest.bare_repo
          @after_hash = work.short_hash
        end
        include_examples 'logs the fetch'
        describe 'everything still works because we fall back' do
          include_examples 'serves some docs', supports_gapped: false
        end
      end
    end
  end
  describe 'after we remove the test branch from the target repo' do
    before(:context) do
      @dest.remove_target_brach 'test'
    end
    it 'logs the fetch' do
      wait_for_logs(/\[deleted\]\s+\(none\)\s+->\s+test/)
      # The leading space in the second line is important because it causes
      # filebeat to group the two log lines.
      expect(logs).to include("\n" + <<~LOGS)
        From #{repo}
         - [deleted]         (none)     -> test
      LOGS
    end
    describe 'for the test branch' do
      let(:branch) { 'test' }
      include_context 'docs for branch'
      include_examples '404s'
    end
  end
  describe 'when we commit a noop change' do
    before(:context) do
      repo = @src.repo 'repo'
      repo.write 'index.asciidoc', <<~ASCIIDOC
        = Title

        [[chapter]]
        == Chapter
        Some text.

        image::resources/readme/cat.jpg[A cat]
        image::resources/readme/example.svg[An example svg]
        image::resources/very_large.jpg[Not a jpg but very big]
      ASCIIDOC
      repo.commit 'test change for test_noop branch2'
      @dest.convert_all @src.conf, target_branch: 'test_noop'
    end
    it 'logs the fetch' do
      wait_for_logs(/\[new branch\]\s+test_noop\s+->\s+test_noop/)
      # The leading space in the second line is important because it causes
      # filebeat to group the two log lines.
      expect(logs).to include("\n" + <<~LOGS)
        From #{repo}
         * [new branch]      test_noop  -> test_noop
      LOGS
    end
    describe 'for the test branch' do
      let(:branch) { 'test_noop' }
      include_context 'docs for branch'
      include_examples 'serves some docs'
      context 'the diff' do
        include_examples 'valid diff'
        it 'is empty' do
          expect(diff).to serve(include("<ul>\n</ul>"))
        end
        it "has a message saying there aren't any differences" do
          expect(diff).to serve(include("<p>There aren't any differences!</p>"))
        end
      end
    end
  end
  describe 'when there are alternative examples' do
    before(:context) do
      # We don't have any examples in our source document so we'll just make a
      # dummy file so the checkout works. This is good enough to make a
      # distinct initial_js_state
      csharp_repo = @src.repo 'csharp'
      csharp_repo.write 'examples/dummy', 'dummy'
      csharp_repo.commit 'add example'

      book = @src.book 'Test'
      book.source(
        csharp_repo,
        'examples',
        alternatives: { source_lang: 'console', alternative_lang: 'csharp' }
      )
      @dest.convert_all @src.conf, target_branch: 'alternative_examples'
    end
    it 'logs the fetch' do
      wait_for_logs(
        /\[new branch\]\s+alternative_examples\s+->\s+alternative_examples/
      )
      # The leading space in the second line is important because it causes
      # filebeat to group the two log lines.
      expect(logs).to include("\n" + <<~LOGS)
        From #{repo}
         * [new branch]      alternative_examples -> alternative_examples
      LOGS
    end
    let(:branch) { 'alternative_examples' }
    let(:expected_js_state) do
      {
        alternatives: {
          console: {
            csharp: { hasAny: false },
          },
        },
      }
    end
    include_context 'docs for branch'
    include_examples 'serves some docs'
  end
  describe 'when the language is something other than `en`' do
    before(:context) do
      book = @src.book 'Test'
      book.lang = 'foo'
      @dest.convert_all @src.conf, target_branch: 'foolang'
    end
    it 'logs the fetch' do
      wait_for_logs(
        /\[new branch\]\s+foolang\s+->\s+foolang/
      )
      # The leading space in the second line is important because it causes
      # filebeat to group the two log lines.
      expect(logs).to include("\n" + <<~LOGS)
        From #{repo}
         * [new branch]      foolang    -> foolang
      LOGS
    end
    let(:branch) { 'foolang' }
    let(:expected_js_state) do
      {
        alternatives: {
          console: {
            csharp: { hasAny: false },
          },
        },
      }
    end
    let(:expected_language) { 'foo' }
    include_context 'docs for branch'
    include_examples 'serves some docs'
  end
  describe "when we can't pull from the repo" do
    before(:context) do
      FileUtils.rm_rf '/tmp/backup'
      FileUtils.mv @dest.bare_repo, '/tmp/backup'
    end
    it 'logs an angry message' do
      wait_for_logs(/Could not read from remote repository./)
    end
  end
  describe 'when we can pull again' do
    before(:context) do
      FileUtils.mv '/tmp/backup', @dest.bare_repo
      @dest.convert_all @src.conf, target_branch: 'restored'
    end
    it 'fetches' do
      wait_for_logs(
        /\[new branch\]\s+restored\s+->\s+restored/
      )
      # The leading space in the second line is important because it causes
      # filebeat to group the two log lines.
      expect(logs).to include("\n" + <<~LOGS)
        From #{repo}
         * [new branch]      restored   -> restored
      LOGS
    end
    let(:branch) { 'restored' }
    include_context 'docs for branch'
    context 'the docs root' do
      it 'contains a link to the current index' do
        expect(guide_root).to serve(doc_body(include(<<~HTML.strip)))
          <a class="ulink" href="test/current/index.html" target="_top">Test</a>
        HTML
      end
      it 'logs access to the docs root' do
        wait_for_access '/'
        expect(logs).to include(<<~LOGS)
          #{watermark} #{host} GET /guide/index.html HTTP/1.1 200
        LOGS
      end
    end
  end
end
