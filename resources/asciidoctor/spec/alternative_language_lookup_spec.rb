# frozen_string_literal: true

require 'tmpdir'
require 'alternative_language_lookup/extension'

RSpec.describe AlternativeLanguageLookup do
  before(:each) do
    Asciidoctor::Extensions.register do
      treeprocessor AlternativeLanguageLookup
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  let(:spec_dir) { File.dirname(__FILE__) }
  let(:example_alternatives) do
    "#{spec_dir}/resources/alternative_language_lookup"
  end

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
    let(:convert_attributes) { { 'alternative_language_lookups' => '' } }
    let(:input) { one_snippet }
    let(:snippet_contents) { 'GET /' }
    include_examples "doesn't modify the output"
  end
  context 'when it is configured to a missing directory' do
    include_context 'convert with logs'
    let(:config) do
      <<~CSV
        console,missing,#{example_alternatives}/missing
      CSV
    end
    let(:convert_attributes) { { 'alternative_language_lookups' => config } }
    let(:input) { one_snippet }
    let(:snippet_contents) { 'GET /' }
    include_examples "doesn't modify the output"
    it 'logs an error for the missing directory' do
      expect(logs).to eq(<<~LOG.strip)
        ERROR: invalid alternative_language_lookups, [#{example_alternatives}/missing] doesn't exist
      LOG
    end
  end
  context 'when it is configured for a different language' do
    include_context 'convert without logs'
    let(:config) do
      <<~CSV
        missing,js,#{example_alternatives}/js
      CSV
    end
    let(:convert_attributes) { { 'alternative_language_lookups' => config } }
    let(:input) { one_snippet }
    let(:snippet_contents) { 'GET /' }
    include_examples "doesn't modify the output"
  end

  context 'when it is configured' do
    let(:config) do
      <<~CSV
        console,js,#{example_alternatives}/js
        console,csharp,#{example_alternatives}/csharp
        console,java,#{example_alternatives}/java
      CSV
    end
    after(:each) do
      FileUtils.remove_entry report_dir
    end
    let(:convert_attributes) do
      {
        'alternative_language_lookups' => config,
        'alternative_language_report_dir' => Dir.mktmpdir('lang_report'),
      }
    end
    let(:report_dir) do
      # read the result of the conversion to populate the dir
      converted
      # return the dir
      convert_attributes['alternative_language_report_dir']
    end
    context "when there aren't any alternatives" do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /no_alternatives' }
      include_examples "doesn't modify the output"
      let(:expected_log) do
        <<~LOG
          * 3fcdfa6097c68c04f3e175dcf3934af6.adoc: <stdin>: line 2
        LOG
      end
      it 'creates a missing alternatives report for js' do
        expect(File.read("#{report_dir}/console/js")).to eq(expected_log)
      end
      it 'creates a missing alternatives report for c#' do
        expect(File.read("#{report_dir}/console/csharp")).to eq(expected_log)
      end
      it 'creates a missing alternative report for java' do
        expect(File.read("#{report_dir}/console/java")).to eq(expected_log)
      end
    end
    context 'when there is a single alternative' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /just_js_alternative' }
      it 'adds the alternative' do
        expect(converted).to eq(<<~DOCBOOK.strip)
          <preface>
          <title></title>
          <programlisting role="default" language="console" linenumbering="unnumbered">#{snippet_contents}</programlisting>
          <programlisting role="alternative" language="js" linenumbering="unnumbered">console.info('just js alternative');</programlisting>
          </preface>
        DOCBOOK
      end
      let(:expected_log) do
        <<~LOG
          * 39f76498cca438ba11af18a7075d24c9.adoc: <stdin>: line 2
        LOG
      end
      it "doesn't create a missing alternative report for js" do
        expect(File).not_to exist("#{report_dir}/console/js")
      end
      it 'creates a missing alternative report for c#' do
        expect(File.read("#{report_dir}/console/csharp")).to eq(expected_log)
      end
      it 'creates a missing alternative report for java' do
        expect(File.read("#{report_dir}/console/java")).to eq(expected_log)
      end
    end
    context 'when all alternatives exist' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /all_alternatives' }
      it 'adds the alternative' do
        expect(converted).to eq(<<~DOCBOOK.strip)
          <preface>
          <title></title>
          <programlisting role="default" language="console" linenumbering="unnumbered">#{snippet_contents}</programlisting>
          <programlisting role="alternative" language="js" linenumbering="unnumbered">console.info('all alternatives');</programlisting>
          <programlisting role="alternative" language="csharp" linenumbering="unnumbered">Console.WriteLine("all alternatives");</programlisting>
          <programlisting role="alternative" language="java" linenumbering="unnumbered">System.out.println("all alternatives");</programlisting>
          </preface>
        DOCBOOK
      end
      it "doesn't create a missing alternative report for js" do
        expect(File).not_to exist("#{report_dir}/console/js")
      end
      it "doesn't create a missing alternative report for c#" do
        expect(File).not_to exist("#{report_dir}/console/csharp")
      end
      it "doesn't create a missing alternative report for java" do
        expect(File).not_to exist("#{report_dir}/console/java")
      end
    end
    context 'when the alternative has characters that must be escaped' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /has_<' }
      it 'adds the alternative' do
        expect(converted).to include(<<~DOCBOOK.strip)
          var searchResponse = _client.Search&lt;Project&gt;(s =&gt; s
              .Query(q =&gt; q
                  .QueryString(m =&gt; m
                      .Query("foo bar")
                  )
              )
          );
        DOCBOOK
      end
    end
    context 'when the alternative includes another file' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /has_include' }
      it 'adds the alternative' do
        expect(converted).to include(<<~CSHARP.strip)
          Console.WriteLine("Hello World!");
        CSHARP
      end
    end
    # NOCOMMIT alternative has matching callouts
    # NOCOMMIT alternative has non-matching callouts (error!)
    context 'when there is an error in the alternative' do
      include_context 'convert with logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /has_error' }
      it 'adds the alternative' do
        expect(converted).to include(<<~DOCBOOK.strip)
          Unresolved directive in ded0ba409b7c66489d5833dc6aa5f696.adoc - include::missing.adoc[]
        DOCBOOK
      end
      it 'logs an error' do
        expect(logs).to eq(<<~LOG.strip)
          ERROR: ded0ba409b7c66489d5833dc6aa5f696.adoc: line 1: include file not found: #{example_alternatives}/csharp/missing.adoc
        LOG
      end
    end
  end
end
