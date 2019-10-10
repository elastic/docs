# frozen_string_literal: true

require 'pathname'
require 'edit_me/extension'

RSpec.describe EditMe do
  before(:each) do
    Asciidoctor::Extensions.register EditMe
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
    include_examples 'standard document part', 'float',
                     %(renderas="sect2">), %(</bridgehead>)
  end

  context 'when edit_urls is configured' do
    let(:edit_urls) do
      <<~CSV
        <stdin>,www.example.com/stdin
        #{spec_dir},www.example.com/spec_dir
      CSV
    end
    let(:convert_attributes) { { 'edit_urls' => edit_urls } }
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

    shared_examples 'standard document part' do |type, title_start, title_end|
      title_start ||= '<title>'
      title_end ||= '</title>'
      context "for a document with #{type}s" do
        shared_examples 'has standard edit links' do
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
        context "that doesn't override edit_url" do
          let(:input) do
            <<~ASCIIDOC
              include::resources/edit_me/#{type}1.adoc[]

              include::resources/edit_me/#{type}2.adoc[]
            ASCIIDOC
          end
          include_examples 'has standard edit links'
        end
        context 'that overrides edit_url' do
          let(:input) do
            <<~ASCIIDOC
              :edit_url: foo
              include::resources/edit_me/#{type}1.adoc[]

              :edit_url: bar
              include::resources/edit_me/#{type}2.adoc[]
            ASCIIDOC
          end
          context 'when overriding the edit_url is allowed' do
            let(:convert_attributes) do
              {
                'edit_urls' => edit_urls,
                'respect_edit_url_overrides' => 'true',
              }
            end
            it "adds a link to #{type} 1" do
              link = '<ulink role="edit_me" url="foo">Edit me</ulink>'
              expect(converted).to include(
                "#{title_start}#{type.capitalize} 1#{link}#{title_end}"
              )
            end
            it "adds a link to #{type} 2" do
              link = '<ulink role="edit_me" url="bar">Edit me</ulink>'
              expect(converted).to include(
                "#{title_start}#{type.capitalize} 2#{link}#{title_end}"
              )
            end
            context 'when overriding to an empty string' do
              let(:input) do
                <<~ASCIIDOC
                  :edit_url:
                  include::resources/edit_me/#{type}1.adoc[]

                  include::resources/edit_me/#{type}2.adoc[]
                ASCIIDOC
              end
              it "doesn't add edit links to #{type} 1" do
                expect(converted).to include(
                  "#{title_start}#{type.capitalize} 1#{title_end}"
                )
              end
              it "doesn't add edit links to #{type} 2" do
                expect(converted).to include(
                  "#{title_start}#{type.capitalize} 2#{title_end}"
                )
              end
            end
          end
          context "when overriding the edit_url isn't allowed" do
            include_examples 'has standard edit links'
          end
        end
      end
    end
    include_examples 'all standard document parts'

    context 'when edit_urls has two matches' do
      let(:convert_attributes) do
        edit_urls = <<~CSV
          <stdin>,www.example.com/stdin
          #{spec_dir},www.example.com/spec_dir
          #{spec_dir}/resources/edit_me/section2.adoc,www.example.com/section2
        CSV
        { 'edit_urls' => edit_urls }
      end
      let(:input) do
        <<~ASCIIDOC
          include::resources/edit_me/section1.adoc[]

          include::resources/edit_me/section2.adoc[]
        ASCIIDOC
      end
      it 'uses the longest match' do
        url = 'www.example.com/section2'
        link = %(<ulink role="edit_me" url="#{url}">Edit me</ulink>)
        expect(converted).to include("<title>Section 2#{link}</title>")
      end
    end
    context 'when edit_urls explictly disables a path' do
      let(:convert_attributes) do
        edit_urls = <<~CSV
          <stdin>,www.example.com/stdin
          #{spec_dir},www.example.com/spec_dir
          #{spec_dir}/resources/edit_me/section2.adoc,<disable>
        CSV
        { 'edit_urls' => edit_urls }
      end
      let(:input) do
        <<~ASCIIDOC
          include::resources/edit_me/section1.adoc[]

          include::resources/edit_me/section2.adoc[]
        ASCIIDOC
      end
      it "doesn't have an edit me link" do
        expect(converted).to include('<title>Section 2</title>')
      end
    end
  end
  context 'when edit_urls is not configured' do
    include_context 'convert without logs'
    context 'for a document with a preface' do
      include_context 'preface'
      it "doesn't add a link to the preface" do
        expect(converted).to include('<title>Preface</title>')
      end
    end

    shared_examples 'standard document part' do |type, title_start, title_end|
      title_start ||= '<title>'
      title_end ||= '</title>'
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
