# frozen_string_literal: true

require 'alternate_language_lookup/extension'

RSpec.describe AlternateLanguageLookup do
  before(:each) do
    Asciidoctor::Extensions.register do
      treeprocessor AlternateLanguageLookup
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  let(:spec_dir) { File.dirname(__FILE__) }
  let(:example_alternates) { "#{spec_dir}/resources/alternate_language_lookup" }

  let(:one_snippet) do
    <<~ASCIIDOC
      [source,console]
      ----
      #{snippet_contents}
      ----
    ASCIIDOC
  end

  shared_examples "doesn't modify the output" do
    it "doesn't modify the output" do
      expect(converted).to eq(<<~DOCBOOK.strip)
        <preface>
        <title></title>
        <programlisting language="console" linenumbering="unnumbered">#{snippet_contents}</programlisting>
        </preface>
      DOCBOOK
    end
  end

  context 'when it is not configured' do
    include_context 'convert without logs'
    let(:input) { one_snippet }
    let(:snippet_contents) { 'GET /' }
    include_examples "doesn't modify the output"
  end
  context 'when it is configured to an empty string' do
    include_context 'convert without logs'
    let(:convert_attributes) { { 'alternate_language_lookups' => '' } }
    let(:input) { one_snippet }
    let(:snippet_contents) { 'GET /' }
    include_examples "doesn't modify the output"
  end
  context 'when it is configured to a missing directory' do
    include_context 'convert with logs'
    let(:config) do
      <<~CSV
        console,missing,#{example_alternates}/missing
      CSV
    end
    let(:convert_attributes) { { 'alternate_language_lookups' => config } }
    let(:input) { one_snippet }
    let(:snippet_contents) { 'GET /' }
    include_examples "doesn't modify the output"
    it 'logs an error for the missing directory' do
      expect(logs).to eq(<<~LOG.strip)
        ERROR: invalid alternate_language_lookups, [#{example_alternates}/missing] doesn't exist
      LOG
    end
  end
  context 'when it is configured for a different language' do
    include_context 'convert without logs'
    let(:config) do
      <<~CSV
        missing,js,#{example_alternates}/js
      CSV
    end
    let(:convert_attributes) { { 'alternate_language_lookups' => config } }
    let(:input) { one_snippet }
    let(:snippet_contents) { 'GET /' }
    include_examples "doesn't modify the output"
  end

  context 'when it is configured' do
    include_context 'convert without logs'
    let(:config) do
      <<~CSV
        console,js,#{example_alternates}/js
        console,c#,#{example_alternates}/c#
        console,java,#{example_alternates}/java
      CSV
    end
    let(:convert_attributes) { { 'alternate_language_lookups' => config } }
    context "when there aren't any alternates" do
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /no_alternates' }
      include_examples "doesn't modify the output"
    end
    context 'when there is a single alternate' do
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /just_js_alternate' }
      it 'adds the alternate' do
        expect(converted).to eq(<<~DOCBOOK.strip)
          <preface>
          <title></title>
          <programlisting language="console" linenumbering="unnumbered">#{snippet_contents}</programlisting>
          <programlisting language="js" linenumbering="unnumbered">console.info('just js alternate');</programlisting>
          </preface>
        DOCBOOK
      end  
    end
  end

end
