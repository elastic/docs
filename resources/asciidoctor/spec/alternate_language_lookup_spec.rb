# frozen_string_literal: true

require 'tmpdir'
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
    let(:config) do
      <<~CSV
        console,js,#{example_alternates}/js
        console,csharp,#{example_alternates}/csharp
        console,java,#{example_alternates}/java
      CSV
    end
    after(:each) do
      FileUtils.remove_entry report_dir
    end
    let(:convert_attributes) do
      {
        'alternate_language_lookups' => config,
        'alternate_language_report_dir' => Dir.mktmpdir('lang_report'),
      }
    end
    let(:report_dir) do
      # read the result of the conversion to populate the dir
      converted
      # return the dir
      convert_attributes['alternate_language_report_dir']
    end
    context "when there aren't any alternates" do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /no_alternates' }
      include_examples "doesn't modify the output"
      let(:expected_log) do
        <<~LOG
          * 8b9717c0c5b44be5ff1fcbdc00979f1a.adoc: <stdin>: line 2
        LOG
      end
      it 'creates a missing alternate report for js' do
        expect(File.read("#{report_dir}/console/js")).to eq(expected_log)
      end
      it 'creates a missing alternate report for c#' do
        expect(File.read("#{report_dir}/console/csharp")).to eq(expected_log)
      end
      it 'creates a missing alternate report for java' do
        expect(File.read("#{report_dir}/console/java")).to eq(expected_log)
      end
    end
    context 'when there is a single alternate' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /just_js_alternate' }
      it 'adds the alternate' do
        expect(converted).to eq(<<~DOCBOOK.strip)
          <preface>
          <title></title>
          <programlisting role="default" language="console" linenumbering="unnumbered">#{snippet_contents}</programlisting>
          <programlisting role="alternate" language="js" linenumbering="unnumbered">console.info('just js alternate');</programlisting>
          </preface>
        DOCBOOK
      end
      let(:expected_log) do
        <<~LOG
          * 10fa89ac4f5f65a6daebfdb7f9051448.adoc: <stdin>: line 2
        LOG
      end
      it "doesn't create a missing alternate report for js" do
        expect(File).not_to exist("#{report_dir}/console/js")
      end
      it 'creates a missing alternate report for c#' do
        expect(File.read("#{report_dir}/console/csharp")).to eq(expected_log)
      end
      it 'creates a missing alternate report for java' do
        expect(File.read("#{report_dir}/console/java")).to eq(expected_log)
      end
    end
    context 'when all alternates exist' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /all_alternates' }
      it 'adds the alternate' do
        expect(converted).to eq(<<~DOCBOOK.strip)
          <preface>
          <title></title>
          <programlisting role="default" language="console" linenumbering="unnumbered">#{snippet_contents}</programlisting>
          <programlisting role="alternate" language="js" linenumbering="unnumbered">console.info('all alternates');</programlisting>
          <programlisting role="alternate" language="csharp" linenumbering="unnumbered">Console.WriteLine("all alternates");</programlisting>
          <programlisting role="alternate" language="java" linenumbering="unnumbered">System.out.println("all alternates");</programlisting>
          </preface>
        DOCBOOK
      end
      it "doesn't create a missing alternate report for js" do
        expect(File).not_to exist("#{report_dir}/console/js")
      end
      it "doesn't create a missing alternate report for c#" do
        expect(File).not_to exist("#{report_dir}/console/csharp")
      end
      it "doesn't create a missing alternate report for java" do
        expect(File).not_to exist("#{report_dir}/console/java")
      end
    end
    context 'when the alternate has characters that must be escaped' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /has_<' }
      it 'adds the alternate' do
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
    context 'when the alternate includes another file' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /has_include' }
      it 'adds the alternate' do
        expect(converted).to include(<<~CSHARP.strip)
          Console.WriteLine("Hello World!");
        CSHARP
      end
    end
    # NOCOMMIT alternate has matching callouts
    # NOCOMMIT alternate has non-matching callouts (error!)
    context 'when there is an error in the alternate' do
      include_context 'convert with logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /has_error' }
      it 'adds the alternate' do
        expect(converted).to include(<<~DOCBOOK.strip)
          Unresolved directive in ded0ba409b7c66489d5833dc6aa5f696.adoc - include::missing.adoc[]
        DOCBOOK
      end
      it 'logs an error' do
        expect(logs).to eq(<<~LOG.strip)
          ERROR: ded0ba409b7c66489d5833dc6aa5f696.adoc: line 1: include file not found: #{example_alternates}/csharp/missing.adoc
        LOG
      end
    end
  end
end
