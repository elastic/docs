# frozen_string_literal: true

require 'net/http'

##
# Test for the air gapped deploy of the docs. For the most part the air gapped
# deploy is the same as a preview that doesn't attempt to update itself so we
# don't test a ton of things here.
RSpec.describe 'air gapped deploy', order: :defined do
  convert_before do |src, dest|
    repo = src.repo_with_index 'repo', <<~ASCIIDOC
      Some text.
    ASCIIDOC
    book = src.book 'Test'
    book.source repo, 'index.asciidoc'
    dest.convert_all src.conf
  end
  before(:context) do
    @air_gapped = @dest.start_air_gapped
  end
  after(:context) do
    @air_gapped&.exit
  end
  let(:air_gapped) { @air_gapped }

  let(:root) { 'http://localhost:8000/guide' }
  let(:books_index) { Net::HTTP.get_response(URI("#{root}/index.html")) }

  context 'the logs' do
    it "don't contain anything git" do
      air_gapped.wait_for_logs(/Built docs are ready/, 10)
      expect(air_gapped.logs).not_to include('Cloning built docs')
      expect(air_gapped.logs).not_to include('git')
    end
  end

  context 'the books index' do
    it 'links to the book' do
      expect(books_index).to serve(doc_body(include(<<~HTML.strip)))
        <a class="ulink" href="test/current/index.html" target="_top">Test</a>
      HTML
    end
    it 'logs the access to the docs root' do
      air_gapped.wait_for_logs %r{localhost:8000 GET /guide/index.html}, 10
      expect(air_gapped.logs).to include(<<~LOGS)
        localhost:8000 GET /guide/index.html HTTP/1.1 200
      LOGS
    end
    it 'uses the air gapped template' do
      expect(books_index).not_to serve(include(<<~HTML.strip))
        https://www.googletagmanager.com/gtag/js
      HTML
    end
  end
end
