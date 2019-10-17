# frozen_string_literal: true

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

  let(:host) { 'localhost' }
  let(:books_index) { air_gapped.get 'guide/index.html', host: host }
  let(:outside_of_guide) do
    air_gapped.get 'cloud/elasticsearch-service/signup', host: host
  end

  context 'the logs' do
    it "don't contain anything git" do
      air_gapped.wait_for_logs(/Built docs are ready/, 10)
      expect(air_gapped.logs).not_to include('Cloning built docs')
      expect(air_gapped.logs).not_to include('git')
    end
  end
  include_examples 'the favicon'

  context 'the books index' do
    it 'links to the book' do
      expect(books_index).to serve(doc_body(include(<<~HTML.strip)))
        <a class="ulink" href="test/current/index.html" target="_top">Test</a>
      HTML
    end
    it 'logs the access to the docs root' do
      air_gapped.wait_for_logs %r{localhost GET /guide/index.html}, 10
      expect(air_gapped.logs).to include(<<~LOGS)
        localhost GET /guide/index.html HTTP/1.1 200
      LOGS
    end
    it 'uses the air gapped template' do
      expect(books_index).not_to serve(include(<<~HTML.strip))
        https://www.googletagmanager.com/gtag/js
      HTML
    end
  end
  context 'for a url outside of the docs' do
    it '404s' do
      expect(outside_of_guide.code).to eq('404')
    end
  end
  context "when the host isn't localhost" do
    let(:host) { 'dot.dot.localhost' }
    it 'we can still serve the books index' do
      expect(books_index).to serve(doc_body(include(<<~HTML.strip)))
        <a class="ulink" href="test/current/index.html" target="_top">Test</a>
      HTML
    end
    it 'logs the access to the funny host' do
      air_gapped.wait_for_logs %r{dot.dot.localhost GET /guide/index.html}, 10
      expect(air_gapped.logs).to include(<<~LOGS)
        dot.dot.localhost GET /guide/index.html HTTP/1.1 200
      LOGS
    end
  end
end
