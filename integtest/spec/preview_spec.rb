# frozen_string_literal: true

require 'net/http'
require 'securerandom'

##
# Test for the `--preview` functionality that is usually deployed in
# Elastic Apps. It previews all branches of the `--target_repo`. The test runs
# everything in the defined order because starting the preview is fairly heavy
# and the preview is designed to update itself as its target repo changes so
# we start it once and play with the target repo during the tests.
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
    @preview.exit
  end
  let(:repo) { @dest.bare_repo.sub '.git', '' }
  let(:preview) { @preview }
  let(:logs) { preview.logs }

  def wait_for_logs(regexp, timeout: 10)
    preview.wait_for_logs(regexp, timeout)
  rescue Timeout::Error
    expect(preview.logs).to match(regexp)
  end

  def wait_for_access(watermark, branch, path)
    wait_for_logs(/^#{watermark} #{branch}.+#{path}.+$/)
  end

  def get(watermark, branch, path)
    uri = URI("http://localhost:8000/#{path}")
    req = Net::HTTP::Get.new(uri)
    # The preview server reads the branch from the `Host` header. It throws out
    # everything after and including the first `.` so you can hit a branch
    # at urls like `http://master.docs-preview.app.elstc.co/`. That implies
    # two things:
    # 1. It won't work for branches with `.` in them.
    # 2. If you don't send a `.` then the entire `Host` header is read as the
    #    branch.
    raise "branches can't contain [.]" if branch.include? '.'

    req['X-Opaque-Id'] = watermark
    req['Host'] = branch
    Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  end

  shared_context 'docs for branch' do
    watermark = SecureRandom.uuid
    let(:watermark) { watermark }
    let(:current_url) { 'guide/test/current' }
    let(:diff) { get watermark, branch, 'diff' }
    let(:robots_txt) { get watermark, branch, 'robots.txt' }
    let(:root) { get watermark, branch, 'guide/index.html' }
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
  end

  it 'logs that the built docs are ready' do
    wait_for_logs(/Built docs are ready/)
  end

  shared_examples 'serves the docs root' do
    it 'serves the docs root' do
      expect(root).to serve(doc_body(include(<<~HTML.strip)))
        <a class="ulink" href="test/current/index.html" target="_top">Test</a>
      HTML
    end
    it 'logs the access to the docs root' do
      wait_for_access watermark, branch, '/guide/index.html'
      expect(logs).to include(<<~LOGS)
        #{watermark} #{branch} GET /guide/index.html HTTP/1.1 200
      LOGS
    end
    it 'serves a "go away" robots.txt' do
      expect(robots_txt).to serve(eq(<<~TXT))
        User-agent: *
        Disallow: /
      TXT
      expect(robots_txt['Content-Type']).to eq('text/plain')
    end
  end
  shared_examples '404s' do
    it '404s for the docs root' do
      expect(root.code).to eq('404')
    end
    it 'logs the access to the docs root' do
      wait_for_access watermark, branch, '/guide/index.html'
      expect(logs).to include(<<~LOGS)
        #{watermark} #{branch} GET /guide/index.html HTTP/1.1 404
      LOGS
    end
    it '404s for the diff' do
      expect(diff.code).to eq('404')
    end
    it 'logs the access to the diff' do
      wait_for_access watermark, branch, '/diff'
      expect(logs).to include(<<~LOGS)
        #{watermark} #{branch} GET /diff HTTP/1.1 404
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
      wait_for_access watermark, branch, '/diff'
      expect(logs).to include(<<~LOGS)
        #{watermark} #{branch} GET /diff HTTP/1.1 200
      LOGS
    end
  end

  describe 'for the master branch' do
    let(:branch) { 'master' }
    include_context 'docs for branch'
    include_examples 'serves the docs root'
    context 'for a JPG' do
      it 'serves the right bytes' do
        bytes = File.open("#{readme_resources}/cat.jpg", 'rb', &:read)
        expect(cat_image).to serve(eq(bytes))
      end
      it 'serves the right Content-Type' do
        cat_image.each_header {|key, value| puts "#{key}: #{value}"}
        expect(cat_image['Content-Type']).to eq('image/jpeg')
      end
    end
    context 'for an SVG' do
      it 'serves the right bytes' do
        bytes = File.open("#{readme_resources}/example.svg", 'rb', &:read)
        expect(svg_image).to serve(eq(bytes))
      end
      it 'serves the right Content-Type' do
        svg_image.each_header {|key, value| puts "#{key}: #{value}"}
        expect(svg_image['Content-Type']).to eq('image/svg+xml')
      end
    end
    it 'serves a very large file' do
      expect(very_large).to serve(eq(very_large_text))
    end
    context 'when you request a directory' do
      it 'redirects to index.html' do
        expect(directory.code).to eq('301')
        expect(directory['Location']).to eq('/guide/index.html')
      end
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
      include_examples 'serves the docs root'
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
      include_examples 'serves the docs root'
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
end
