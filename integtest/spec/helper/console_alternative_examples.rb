# frozen_string_literal: true

RSpec.shared_examples 'README-like console alternatives' do |path|
  page_context "#{path}/chapter.html" do
    it 'contains the default example' do
      has_roles = 'has-js has-csharp'
      console_widget = <<~HTML.strip
        <div class="console_widget default #{has_roles}" data-snippet="snippets/1.console"></div>
      HTML
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper default #{has_roles} lang-console"><pre class="default #{has_roles} programlisting prettyprint lang-console">GET /_search
        {
            "query": "foo bar" <a id="CO1-1"></a><span><img src="images/icons/callouts/1.png" alt="" /></span>
        }</pre></div>#{console_widget}<div class="default #{has_roles} lang-console calloutlist">
      HTML
      # The last line is important: we need the snippet to be followed
      # immediately by the console widget and then immediately by the callout
      # list.
    end
    it 'contains the js example' do
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper alternative lang-js"><pre class="alternative programlisting prettyprint lang-js">const result = await client.search({
          body: { query: 'foo bar' } <a id="A0-CO1-1"></a><span><img src="images/icons/callouts/1.png" alt="" /></span>
        })</pre></div><div class="alternative lang-js calloutlist">
      HTML
      # The last line is important: we need the snippet to be followed
      # immediately by the callout list.
    end
    it 'contains the csharp example' do
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper alternative lang-csharp"><pre class="alternative programlisting prettyprint lang-csharp">var searchResponse = _client.Search&lt;Project&gt;(s =&gt; s
            .Query(q =&gt; q
                .QueryString(m =&gt; m
                    .Query("foo bar") <a id="A1-CO1-1"></a><span><img src="images/icons/callouts/1.png" alt="" /></span>
                )
            )
        );</pre></div><div class="alternative lang-csharp calloutlist">
      HTML
    end
  end
  file_context "#{path}/alternatives_report.adoc" do
    it 'has a report on the example with all alternatives' do
      expect(contents).to include(<<~ASCIIDOC)
        === index.asciidoc: line 6: 8a7e0a79b1743d5fd94d79a7106ee930
        [source,console]
        ----
        GET /_search
        {
            "query": "foo bar" \\<1>
        }
        ----
        |===
        | js | csharp

        | &check; | &check;
        |===
      ASCIIDOC
    end
    it 'has a report on the example without any alternatives' do
      expect(contents).to include(<<~ASCIIDOC)
        === index.asciidoc: line 15: d21765565081685a36dfc4af89e7cece
        [source,console]
        ----
        GET /_search
        {
            "query": "missing"
        }
        ----
        |===
        | js | csharp

        | &cross; | &cross;
        |===
      ASCIIDOC
    end
  end
end
