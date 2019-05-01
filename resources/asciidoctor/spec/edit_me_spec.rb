# frozen_string_literal: true

require 'pathname'
require 'edit_me/extension'

RSpec.describe EditMe do
  before(:each) do
    Asciidoctor::Extensions.register do
      tree_processor EditMe
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  let(:spec_dir) { __dir__ }

  context 'when edit_urls is invalid' do
    include_context 'convert with logs'
    let(:input) { 'Words' }
    context 'because it is missing an edit url' do
      let(:convert_attributes) { { 'edit_urls' => '<stdin>' } }
      it 'emits an error' do
        expect(logs).to include('ERROR: invalid edit_urls, no url')
      end
    end
    context 'because it is missing the toplevel' do
      let(:convert_attributes) { { 'edit_urls' => ',http://example.com' } }
      it 'emits an error' do
        expect(logs).to include('ERROR: invalid edit_urls, no toplevel')
      end
    end
  end

  shared_context 'preface' do
    let(:input) do
      <<~ASCIIDOC
        :preface-title: Preface
        Words.
      ASCIIDOC
    end
  end

  ##
  # Includes `standard document part` for every part of the document that we
  # can test using common code. Before including this in a context you have to
  # define a `shared_examples 'standard document part'` that is appropriate to
  # that context.
  shared_examples 'all standard document parts' do
    include_examples 'standard document part', 'chapter'
    include_examples 'standard document part', 'section'
    include_examples 'standard document part', 'appendix'
    include_examples 'standard document part', 'glossary'
    include_examples 'standard document part', 'bibliography'
    include_examples 'standard document part', 'dedication'
    include_examples 'standard document part', 'colophon'
    include_examples 'standard document part', 'float', %(renderas="sect2">), %(</bridgehead>)
  end

  context 'when edit_urls is configured' do
    let(:convert_attributes) do
      edit_urls = <<~CSV
        <stdin>,www.example.com/stdin
        #{spec_dir},www.example.com/spec_dir
      CSV
      { 'edit_urls' => edit_urls }
    end
    let(:stdin_link) do
      '<ulink role="edit_me" url="www.example.com/stdin">Edit me</ulink>'
    end
    def spec_dir_link(file)
      url = "www.example.com/spec_dir/resources/edit_me/#{file}"
      %(<ulink role="edit_me" url="#{url}">Edit me</ulink>)
    end
    include_context 'convert without logs'
    context 'for a document with a preface' do
      include_context 'preface'
      it 'adds a link to the preface' do
        expect(converted).to include("<title>Preface#{stdin_link}</title>")
      end
    end

    shared_examples 'standard document part' do |type, title_start = '<title>', title_end = '</title>'|
      context "for a document with #{type}s" do
        let(:input) do
          <<~ASCIIDOC
            include::resources/edit_me/#{type}1.adoc[]

            include::resources/edit_me/#{type}2.adoc[]
          ASCIIDOC
        end
        it "adds a link to #{type} 1" do
          link = spec_dir_link "#{type}1.adoc"
          expect(converted).to include(
            "#{title_start}#{type.capitalize} 1#{link}#{title_end}"
          )
        end
        it "adds a link to #{type} 2" do
          link = spec_dir_link "#{type}2.adoc"
          expect(converted).to include(
            "#{title_start}#{type.capitalize} 2#{link}#{title_end}"
          )
        end
      end
    end
    include_examples 'all standard document parts'
  end
  context 'when edit_urls is not configured' do
    include_context 'convert without logs'
    context 'for a document with a preface' do
      include_context 'preface'
      it "doesn't add a link to the preface" do
        expect(converted).to include("<title>Preface</title>")
      end
    end

    shared_examples 'standard document part' do |type, title_start = '<title>', title_end = '</title>'|
      context "for a document with #{type}s" do
        let(:input) do
          <<~ASCIIDOC
            include::resources/edit_me/#{type}1.adoc[]

            include::resources/edit_me/#{type}2.adoc[]
          ASCIIDOC
        end
        it "doesn't add a link to #{type} 1" do
          expect(converted).to include(
            "#{title_start}#{type.capitalize} 1#{title_end}"
          )
        end
        it "doesn't add a link to #{type} 2" do
          expect(converted).to include(
            "#{title_start}#{type.capitalize} 2#{title_end}"
          )
        end
      end
    end
    include_examples 'all standard document parts'
  end
end
