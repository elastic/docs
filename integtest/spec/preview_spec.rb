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
  repo_root = File.expand_path '../../', __dir__
  convert_before do |src, dest|
    repo = src.repo_with_index 'repo', <<~ASCIIDOC
      Some text.

      image::resources/cat.jpg[A cat]
    ASCIIDOC
    repo.cp "#{repo_root}/resources/cat.jpg", 'resources/cat.jpg'
    repo.commit 'add cat image'
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

    req['Watermark'] = watermark
    req['Host'] = branch
    Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  end

  shared_context 'docs for branch' do
    watermark = SecureRandom.uuid
    let(:watermark) { watermark }
    let(:root) { get watermark, branch, 'guide/index.html' }
    let(:current_url) { 'guide/test/current' }
    let(:cat_image) do
      get watermark, branch, "#{current_url}/resources/cat.jpg"
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
  end

  describe 'for the master branch' do
    let(:branch) { 'master' }
    include_context 'docs for branch'
    include_examples 'serves the docs root'
    it 'serves an image' do
      bytes = File.open("#{repo_root}/resources/cat.jpg", 'rb', &:read)
      expect(cat_image).to serve(doc_body(eq(bytes)))
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
      repo.write 'index.asciidoc', 'Some text.'
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
end
