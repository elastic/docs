# frozen_string_literal: true

RSpec.shared_examples 'README-like console alternatives' do |path|
  page_context "#{path}/chapter.html" do
    it 'contains the default example' do
      console_widget = <<~HTML.strip
        <div class="console_widget default" data-snippet="snippets/1.console"></div>
      HTML
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper default lang-console"><pre class="default programlisting prettyprint lang-console">GET /_search
        {
            "query": "foo bar" <a id="CO1-1"></a><span><img src="images/icons/callouts/1.png" alt="" /></span>
        }</pre></div>#{console_widget}<div class="default lang-console calloutlist">
      HTML
      # The last line is important: we need the snippet to be followed
      # immediately by the console widget and then immediately by the callout
      # list.
    end
    it 'contains the js example' do
      expect(body).to include(<<~HTML.strip)
        <div class="pre_wrapper alternative lang-js"><pre class="alternative programlisting prettyprint lang-js">const result = await client.search({
          body: { query: 'foo bar' } <a id="js-8a7e0a79b1743d5fd94d79a7106ee930-CO1-1"></a><span><img src="images/icons/callouts/1.png" alt="" /></span>
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
                    .Query("foo bar") <a id="csharp-8a7e0a79b1743d5fd94d79a7106ee930-CO1-1"></a><span><img src="images/icons/callouts/1.png" alt="" /></span>
                )
            )
        );</pre></div><div class="alternative lang-csharp calloutlist">
      HTML
    end
  end
  file_context "#{path}/missing_alternatives/console/js" do
    it 'contains only the missing example' do
      expect(contents).to eq(<<~LOG)
        * d21765565081685a36dfc4af89e7cece.adoc: index.asciidoc: line 15
      LOG
    end
  end
  file_context "#{path}/missing_alternatives/console/csharp" do
    it 'contains only the missing example' do
      expect(contents).to eq(<<~LOG)
        * d21765565081685a36dfc4af89e7cece.adoc: index.asciidoc: line 15
      LOG
    end
  end
end
