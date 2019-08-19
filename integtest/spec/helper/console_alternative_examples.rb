# frozen_string_literal: true

RSpec.shared_examples 'README-like console alternatives' do |path|
  page_context "#{path}/chapter.html" do
    let(:has_classes) { 'has-js has-csharp' }
    let(:console_widget) do
      <<~HTML.strip
        <div class="console_widget #{has_classes}" data-snippet="snippets/1.console"></div>
      HTML
    end
    it 'contains the js listing followed by the csharp listing' do
      expect(body).to include(<<~HTML.strip)
        </div><div class="pre_wrapper alternative lang-js"><pre class="alternative programlisting prettyprint lang-js">const result = await client.search({
          body: { query: 'foo bar' } <a id="A0-CO1-1"></a><i class="conum" data-value="1"></i>
        })</pre></div><div class="pre_wrapper alternative lang-csharp">
      HTML
    end
    it 'contains the csharp listing followed by the default listing' do
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper alternative lang-csharp"><pre class="alternative programlisting prettyprint lang-csharp">var searchResponse = _client.Search&lt;Project&gt;(s =&gt; s
            .Query(q =&gt; q
                .QueryString(m =&gt; m
                    .Query("foo bar") <a id="A1-CO1-1"></a><i class="conum" data-value="1"></i>
                )
            )
        );</pre></div><div class="pre_wrapper default #{has_classes} lang-console">
      HTML
    end
    it 'contains the default listing followed by the console widget' do
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper default #{has_classes} lang-console"><pre class="default #{has_classes} programlisting prettyprint lang-console">GET /_search
        {
            "query": "foo bar" <a id="CO1-1"></a><i class="conum" data-value="1"></i>
        }</pre></div>#{console_widget}
      HTML
    end
    it 'contains the console widget followed by the js calloutlist' do
      expect(body).to include(<<~HTML.strip)
        #{console_widget}<div class="alternative lang-js calloutlist">
      HTML
    end
    it 'contains the js calloutlist followed by the csharp calloutlist' do
      expect(body).to include(<<~HTML.strip)
        js</p></td></tr></table></div><div class="alternative lang-csharp calloutlist">
      HTML
    end
    it 'contains the csharp calloutlist followed by the default calloutlist' do
      expect(body).to include(<<~HTML.strip)
        csharp</p></td></tr></table></div><div class="default #{has_classes} lang-console calloutlist">
      HTML
    end
    context 'the initial js state' do
      it 'contains the available alternatives' do
        expect(initial_js_state).to include(
          alternatives: {
            console: {
              js: { hasAny: true },
              csharp: { hasAny: true },
              java: { hasAny: false },
            },
          }
        )
      end
    end
  end
  file_context "#{path}/alternatives_report.adoc" do
    it 'has a report on the example with all alternatives' do
      expect(contents).to include(<<~ASCIIDOC)
        === index.asciidoc: line 6: 8a7e0a79b1743d5fd94d79a7106ee930.adoc
        [source,console]
        ----
        GET /_search
        {
            "query": "foo bar" \\<1>
        }
        ----
        |===
        | js | csharp | java

        | &check; | &check; | &cross;
        |===
      ASCIIDOC
    end
    it 'has a report on the example without any alternatives' do
      expect(contents).to include(<<~ASCIIDOC)
        === index.asciidoc: line 15: d21765565081685a36dfc4af89e7cece.adoc
        [source,console]
        ----
        GET /_search
        {
            "query": "missing"
        }
        ----
        |===
        | js | csharp | java

        | &cross; | &cross; | &cross;
        |===
      ASCIIDOC
    end
  end
end
