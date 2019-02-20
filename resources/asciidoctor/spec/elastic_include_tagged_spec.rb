# frozen_string_literal: true

require 'elastic_include_tagged/extension'

RSpec.describe ElasticIncludeTagged do
  before(:each) do
    Asciidoctor::Extensions.register do
      include_processor ElasticIncludeTagged
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  it "includes a tag" do
    actual = convert <<~ASCIIDOC
      == Example
      [source,java]
      ----
      include::elastic-include-tagged:resources/elastic_include_tagged/Example.java[t1]
      ----
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="java" linenumbering="unnumbered">System.err.println("I'm an example");
      for (int i = 0; i &lt; 10; i++) {
          System.err.println(i); <co id="CO1-1"/>
      }</programlisting>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "includes a different tag" do
    actual = convert <<~ASCIIDOC
      == Example
      ["source","java",subs="attributes,callouts,macros"]
      ----
      include::elastic-include-tagged:resources/elastic_include_tagged/Example.java[t2]
      ----
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="java" linenumbering="unnumbered">System.err.println("I'm another example");</programlisting>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "empty tags are supported" do
    actual = convert <<~ASCIIDOC
      == Example
      ["source","java",subs="attributes,callouts,macros"]
      ----
      include::elastic-include-tagged:resources/elastic_include_tagged/Example.java[empty]
      ----
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="java" linenumbering="unnumbered"></programlisting>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "tags without leading spaces are ugly but supported" do
    actual = convert <<~ASCIIDOC
      == Example
      ["source","java",subs="attributes,callouts,macros"]
      ----
      include::elastic-include-tagged:resources/elastic_include_tagged/Example.java[no_leading_space]
      ----
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="java" linenumbering="unnumbered">System.err.println("no leading space");</programlisting>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "warns if the file doesn't exist" do
    input = <<~ASCIIDOC
      include::elastic-include-tagged:resources/elastic_include_tagged/DoesNotExist.java[doesn't-matter]
    ASCIIDOC
    expected = <<~DOCBOOK
      <preface>
      <title></title>
      <simpara>Unresolved directive in &lt;stdin&gt; - include::resources/elastic_include_tagged/DoesNotExist.java[{1&#8658;"doesn&#8217;t-matter"}]</simpara>
      </preface>
    DOCBOOK
    actual = convert input, {}, match(/<stdin>: line 2: include file not found/)
    expect(actual).to eq(expected.strip)
  end

  it "warns if the start tag is missing" do
    input = <<~ASCIIDOC
      include::elastic-include-tagged:resources/elastic_include_tagged/Example.java[missing-start]
    ASCIIDOC
    actual = convert input, {}, match(/<stdin>: line 2: elastic-include-tagged missing start tag \[missing-start\]/)
    expect(actual).to eq('')
  end

  it "warns if the end tag is missing" do
    input = <<~ASCIIDOC
      include::elastic-include-tagged:resources/elastic_include_tagged/Example.java[missing-end]
    ASCIIDOC
    expected = <<~DOCBOOK
      <preface>
      <title></title>
      <simpara>System.err.println("this tag doesn&#8217;t have any end");</simpara>
      </preface>
    DOCBOOK
    actual = convert input, {}, match(%r{resources/elastic_include_tagged/Example.java: line \d+: elastic-include-tagged missing end tag \[missing-end\]})
    expect(actual).to eq(expected.strip)
  end

  it "isn't invoked by include-tagged::" do
    actual = convert <<~ASCIIDOC
      == Example
      ["source","java",subs="attributes,callouts,macros"]
      ----
      include-tagged::resources/elastic_include_tagged/Example.java[t1]
      ----
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="java" linenumbering="unnumbered">include-tagged::resources/elastic_include_tagged/Example.java[t1]</programlisting>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end
end
