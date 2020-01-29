# frozen_string_literal: true

require 'json'

module ConsoleExamples
  README_LIKE = <<~ASCIIDOC
    When you execute this:
    [source,console]
    ----------------------------------
    GET /_search
    {
        "query": "foo bar" <1>
    }
    ----------------------------------
    <1> Here's the explanation

    The result is this:
    [source,console-result]
    ----------------------------------
    {
        "hits": {
            "total": { "value": 0, "relation": "eq" },
            "hits": []
        }
    }
    ----------------------------------

    This one doesn't have an alternative:
    [source,console]
    ----------------------------------
    GET /_search
    {
        "query": "missing"
    }
    ----------------------------------
  ASCIIDOC
end

RSpec.shared_examples 'README-like console alternatives' do |raw_path, path|
  page_context "#{path}/chapter.html" do
    let(:has_classes) { 'has-js has-csharp' }
    let(:console_widget) do
      <<~HTML.strip
        <div class="console_widget #{has_classes}" data-snippet="snippets/1.console"></div>
      HTML
    end
    it 'contains the js listing followed by the csharp listing' do
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper lang-js alternative">
        <pre class="programlisting prettyprint lang-js alternative">const result = await client.search({
          body: { query: 'foo bar' } <a id="A0-CO1-1"></a><i class="conum" data-value="1"></i>
        })</pre>
        </div>
        <div class="pre_wrapper lang-csharp alternative">
      HTML
    end
    it 'contains the csharp listing followed by the default listing' do
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper lang-csharp alternative">
        <pre class="programlisting prettyprint lang-csharp alternative">var searchResponse = _client.Search&lt;Project&gt;(s =&gt; s
            .Query(q =&gt; q
                .QueryString(m =&gt; m
                    .Query("foo bar") <a id="A1-CO1-1"></a><i class="conum" data-value="1"></i>
                )
            )
        );</pre>
        </div>
        <a id="8a7e0a79b1743d5fd94d79a7106ee930"></a>
        <div class="pre_wrapper lang-console default #{has_classes}">
      HTML
    end
    it 'contains the default listing followed by the console widget' do
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper lang-console default #{has_classes}">
        <pre class="programlisting prettyprint lang-console default #{has_classes}">GET /_search
        {
            "query": "foo bar" <a id="CO1-1"></a><i class="conum" data-value="1"></i>
        }</pre>
        </div>
        #{console_widget}
      HTML
    end
    it 'contains the console widget followed by the js calloutlist' do
      expect(body).to include(<<~HTML.strip)
        #{console_widget}
        <div class="calloutlist alternative lang-js">
      HTML
    end
    it 'contains the js calloutlist followed by the csharp calloutlist' do
      expect(body).to include(<<~HTML.strip)
        js</p>
        </td>
        </tr>
        </table>
        </div>
        <div class="calloutlist alternative lang-csharp">
      HTML
    end
    it 'contains the csharp calloutlist followed by the default calloutlist' do
      expect(body).to include(<<~HTML.strip)
        csharp</p>
        </td>
        </tr>
        </table>
        </div>
        <div class="calloutlist default #{has_classes} lang-console">
      HTML
    end
    context 'the initial js state' do
      it 'contains the available alternatives' do
        expect(contents).to initial_js_state(
          include(
            alternatives: {
              console: {
                js: { hasAny: true },
                csharp: { hasAny: true },
                java: { hasAny: false },
              },
            }
          )
        )
      end
    end
  end
  file_context "#{raw_path}/alternatives_report.json" do
    let(:parsed) { JSON.parse contents, symbolize_names: true }
    it 'has a report on the example with all alternatives' do
      expect(parsed).to include(
        source_location: { file: 'index.asciidoc', line: 7 },
        digest: '8a7e0a79b1743d5fd94d79a7106ee930',
        lang: 'console',
        found: %w[js csharp],
        source: <<~ASCIIDOC.strip
          GET /_search
          {
              "query": "foo bar" <1>
          }
        ASCIIDOC
      )
    end
    it 'has a report on the example result' do
      expect(parsed).to include(
        source_location: { file: 'index.asciidoc', line: 17 },
        digest: '9fa2da152878d1d5933d483a3c2af35e',
        lang: 'console-result',
        found: %w[js],
        source: <<~JSON.strip
          {
              "hits": {
                  "total": { "value": 0, "relation": "eq" },
                  "hits": []
              }
          }
        JSON
      )
    end
    it 'has a report on the example without any alternatives' do
      expect(parsed).to include(
        source_location: { file: 'index.asciidoc', line: 28 },
        digest: 'd21765565081685a36dfc4af89e7cece',
        lang: 'console',
        found: [],
        source: <<~ASCIIDOC.strip
          GET /_search
          {
              "query": "missing"
          }
        ASCIIDOC
      )
    end
  end
  context "#{path}/alternatives_report.json" do
    it "doesn't exist" do
      expect(dest_file("#{path}/alternatives_report.json")).not_to file_exist
    end
  end
  file_context "#{raw_path}/alternatives_summary.json" do
    let(:parsed) { JSON.parse contents, symbolize_names: true }
    it 'has proper counts' do
      expect(parsed).to include(
        console: {
          alternatives: {
            js: { found: 2 },
            csharp: { found: 1 },
            java: { found: 0 },
          },
          total: 3,
        }
      )
    end
  end
  context "#{path}/alternatives_summary.json" do
    it "doesn't exist" do
      expect(dest_file("#{path}/alternatives_summary.json")).not_to file_exist
    end
  end
end
