# frozen_string_literal: true

require 'json'
require 'tempfile'
require 'alternative_language_lookup/extension'

RSpec.describe AlternativeLanguageLookup::AlternativeLanguageLookup do
  before(:each) do
    Asciidoctor::Extensions.register do
      treeprocessor AlternativeLanguageLookup::AlternativeLanguageLookup
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
      expect(converted).to eq <<~HTML.strip
        <div id="preamble">
        <div class="sectionbody">
        <div class="listingblock">
        <div class="content">
        <pre class="highlight"><code class="language-console" data-lang="console">#{snippet_contents}</code></pre>
        </div>
        </div>
        </div>
        </div>
      HTML
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
    # Important: we have to keep a hard reference to these tempfile objects
    # until the test is done so they aren't deleted.
    let(:report_file) { Tempfile.new %w[alternatives_report .json] }
    let(:summary_file) { Tempfile.new %w[alternatives_summary .json] }
    let(:convert_attributes) do
      {
        'alternative_language_lookups' => config,
        'alternative_language_report' => report_file.path,
        'alternative_language_summary' => summary_file.path,
      }
    end
    let(:report) do
      # read the result of the conversion to populate the report
      converted
      # grab the contents
      txt = File.read report_file.path
      JSON.parse txt, symbolize_names: true
    end
    let(:summary) do
      # read the result of the conversion to populate the summary
      converted
      # grab the contents
      txt = File.read summary_file.path
      JSON.parse txt, symbolize_names: true
    end
    context "when there aren't any alternatives" do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /no_alternatives' }
      include_examples "doesn't modify the output"
      context 'the alternatives report' do
        it 'contains an entry for the snippet' do
          expect(report).to eq(
            [
              {
                source_location: { file: '<stdin>', line: 2 },
                digest: '3fcdfa6097c68c04f3e175dcf3934af6',
                lang: 'console',
                found: [],
                source: snippet_contents,
              },
            ]
          )
        end
      end
      context 'the summary' do
        it 'shows everything as missing' do
          expect(summary).to eq(
            console: {
              total: 1,
              alternatives: {
                js: { found: 0 },
                csharp: { found: 0 },
                java: { found: 0 },
              },
            }
          )
        end
      end
    end
    context 'when there is a single alternative' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /just_js_alternative' }
      context 'the conversion' do
        it 'contains the existing alternative' do
          expect(converted).to include <<~HTML
            <div class="listingblock alternative">
            <div class="content">
            <pre class="highlight"><code class="language-js" data-lang="js">console.info('just js alternative');</code></pre>
            </div>
            </div>
          HTML
        end
        it 'contains the default' do
          expect(converted).to include <<~HTML
            <div class="listingblock default has-js">
            <div class="content">
            <pre class="highlight"><code class="language-console" data-lang="console">GET /just_js_alternative</code></pre>
            </div>
            </div>
          HTML
        end
        it "doesn't contain any missing alternative" do
          expect(converted).not_to include 'data-lang="csharp"'
          expect(converted).not_to include 'data-lang="java"'
        end
      end
      context 'the alternatives report' do
        it 'shows only js populated' do
          expect(report).to eq(
            [
              {
                source_location: { file: '<stdin>', line: 2 },
                digest: '39f76498cca438ba11af18a7075d24c9',
                lang: 'console',
                found: ['js'],
                source: snippet_contents,
              },
            ]
          )
        end
      end
      context 'the summary' do
        it 'shows only js found' do
          expect(summary).to eq(
            console: {
              total: 1,
              alternatives: {
                js: { found: 1 },
                csharp: { found: 0 },
                java: { found: 0 },
              },
            }
          )
        end
      end
    end
    context 'when all alternatives exist' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /all_alternatives' }
      context 'the conversion' do
        it 'contains the js alternative' do
          expect(converted).to include <<~HTML
            <div class="listingblock alternative">
            <div class="content">
            <pre class="highlight"><code class="language-js" data-lang="js">console.info('all alternatives');</code></pre>
            </div>
            </div>
          HTML
        end
        it 'contains the csharp alternative' do
          expect(converted).to include <<~HTML
            <div class="listingblock alternative">
            <div class="content">
            <pre class="highlight"><code class="language-csharp" data-lang="csharp">Console.WriteLine("all alternatives");</code></pre>
            </div>
            </div>
          HTML
        end
        it 'contains the java alternative' do
          expect(converted).to include <<~HTML
            <div class="listingblock alternative">
            <div class="content">
            <pre class="highlight"><code class="language-java" data-lang="java">System.out.println("all alternatives");</code></pre>
            </div>
            </div>
          HTML
        end
        it 'contains the contains the default' do
          expect(converted).to include <<~HTML
            <div class="listingblock default has-js has-csharp has-java">
            <div class="content">
            <pre class="highlight"><code class="language-console" data-lang="console">GET /all_alternatives</code></pre>
            </div>
            </div>
          HTML
        end
      end
      context 'the alternatives report' do
        it 'shows all languages populated' do
          expect(report).to eq(
            [
              {
                source_location: { file: '<stdin>', line: 2 },
                digest: '5712902c12d9db15d01e8639ece9ec84',
                lang: 'console',
                found: %w[js csharp java],
                source: snippet_contents,
              },
            ]
          )
        end
      end
      context 'the summary' do
        it 'shows only js found' do
          expect(summary).to eq(
            console: {
              total: 1,
              alternatives: {
                js: { found: 1 },
                csharp: { found: 1 },
                java: { found: 1 },
              },
            }
          )
        end
      end
    end
    context 'when there are alternative results' do
      include_context 'convert without logs'
      let(:input) do
        <<~ASCIIDOC
          [source,console]
          ----
          #{snippet_contents}
          ----

          [source,console-result]
          ----
          #{result_contents}
          ----
        ASCIIDOC
      end
      let(:snippet_contents) { 'GET /just_js_alternative' }
      let(:result_contents) { '{"just_js_result": {}}' }
      context 'the conversion' do
        it 'contain the alternative request' do
          expect(converted).to include <<~HTML.strip
            <code class="language-js" data-lang="js">
          HTML
        end
        it 'contain the default request' do
          expect(converted).to include <<~HTML.strip
            <code class="language-console" data-lang="console">
          HTML
        end
        it 'contain the alternative result' do
          expect(converted).to include <<~HTML.strip
            <code class="language-js-result" data-lang="js-result">
          HTML
        end
        it 'contain the default result' do
          expect(converted).to include <<~HTML.strip
            <code class="language-console-result" data-lang="console-result">
          HTML
        end
      end
      context 'the alternatives report' do
        it 'includes the request snippet' do
          expect(report).to include(
            source_location: { file: '<stdin>', line: 2 },
            digest: '39f76498cca438ba11af18a7075d24c9',
            lang: 'console',
            found: ['js'],
            source: snippet_contents
          )
        end
        it 'includes the result snippet' do
          expect(report).to include(
            source_location: { file: '<stdin>', line: 7 },
            digest: 'c4f54085e4784ead2ef4a758d03edd16',
            lang: 'console-result',
            found: ['js'],
            source: result_contents
          )
        end
      end
      context 'the summary' do
        it 'counts the result' do
          expect(summary).to eq(
            console: {
              total: 2,
              alternatives: {
                js: { found: 2 },
                csharp: { found: 0 },
                java: { found: 0 },
              },
            }
          )
        end
      end
    end
    context 'when the alternative has characters that must be escaped' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /has_<' }
      it 'adds the alternative' do
        expect(converted).to include <<~HTML.strip
          var searchResponse = _client.Search&lt;Project&gt;(s =&gt; s
              .Query(q =&gt; q
                  .QueryString(m =&gt; m
                      .Query("foo bar")
                  )
              )
          );
        HTML
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
    context 'when the alternative is in a subdirectory' do
      include_context 'convert without logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /in_subdir' }
      it 'adds the alternative' do
        expect(converted).to include(<<~CSHARP.strip)
          Console.WriteLine("In subdir");
        CSHARP
      end
    end
    context 'when there are callouts' do
      include_context 'convert without logs'
      let(:input) do
        <<~ASCIIDOC
          [source,console]
          ----
          GET /there_are_callouts <1> <2>
          ----
          <1> a
          <2> b
        ASCIIDOC
      end
      it 'inserts the alternative code above the default code' do
        expect(converted).to include <<~HTML
          <pre class="highlight"><code class="language-csharp" data-lang="csharp">Console.WriteLine("there are callouts"); <b class="conum">(1)</b> <b class="conum">(2)</b></code></pre>
          </div>
          </div>
          <div class="listingblock default has-csharp">
          <div class="content">
          <pre class="highlight"><code class="language-console" data-lang="console">GET /there_are_callouts <b class="conum">(1)</b> <b class="conum">(2)</b></code></pre>
        HTML
      end
      it 'inserts the alternative callouts above the default callouts' do
        expect(converted).to include <<~HTML
          <div class="colist arabic alternative lang-csharp">
          <ol>
          <li>
          <p>csharp a</p>
          </li>
          <li>
          <p>csharp b</p>
          </li>
          </ol>
          </div>
          <div class="colist arabic default has-csharp lang-console">
        HTML
      end
    end
    context 'when there is an error in the alternative' do
      include_context 'convert with logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /has_error' }
      it 'adds the alternative with the error text' do
        expect(converted).to include <<~HTML.strip
          include::missing.adoc[]
        HTML
      end
      it 'logs an error' do
        expect(logs).to eq(<<~LOG.strip)
          ERROR: resources/alternative_language_lookup/csharp/ded0ba409b7c66489d5833dc6aa5f696.adoc: line 3: include file not found: #{example_alternatives}/csharp/missing.adoc
        LOG
      end
    end
    context 'when the alternative has the wrong language' do
      include_context 'convert with logs'
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /bad_language' }
      it "doesn't add the alternative" do
        expect(converted).not_to include('Console.WriteLine')
      end
      it 'logs a warning' do
        expect(logs).to eq(<<~LOG.strip)
          WARN: resources/alternative_language_lookup/csharp/fcac4757ba45b9b14f316eb9bda58584.adoc: line 2: Alternative language listing must have lang=csharp but was not_csharp.
        LOG
      end
    end
    context 'when the configuration has duplicates' do
      include_context 'convert with logs'
      let(:config) do
        <<~CSV
          console,js,#{example_alternatives}/js
          console,js,#{example_alternatives}/js
        CSV
      end
      let(:input) { one_snippet }
      let(:snippet_contents) { 'GET /will_fail' }
      it 'logs an error' do
        expect(logs).to eq(<<~LOG.strip)
          ERROR: invalid alternative_language_lookups, duplicate alternative_lang [js]
        LOG
      end
    end
  end
end
