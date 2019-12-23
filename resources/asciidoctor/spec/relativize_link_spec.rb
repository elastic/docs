# frozen_string_literal: true

require 'relativize_link/extension'

RSpec.describe RelativizeLink do
  before(:each) do
    Asciidoctor::Extensions.register RelativizeLink
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  context 'when not configured' do
    include_context 'convert without logs'
    let(:input) { 'https://www.elastic.co/guide/foo[foo]' }
    it "doesn't do anything" do
      expect(converted).to include <<~HTML.strip
        <a href="https://www.elastic.co/guide/foo">foo</a>
      HTML
    end
  end
  context 'when configured' do
    include_context 'convert without logs'
    let(:convert_attributes) do
      { 'relativize-link' => 'https://www.elastic.co/' }
    end
    context 'when the url matches' do
      let(:input) { 'https://www.elastic.co/guide/foo[foo]' }
      it 'relativizes the link' do
        expect(converted).to include <<~HTML.strip
          <a href="/guide/foo">foo</a>
        HTML
      end
    end
    context "when the url doesn't match" do
      let(:input) { 'https://not.elastic.co/guide/foo[foo]' }
      it "doesn't do anything" do
        expect(converted).to include <<~HTML.strip
          <a href="https://not.elastic.co/guide/foo">foo</a>
        HTML
      end
    end
  end
end
