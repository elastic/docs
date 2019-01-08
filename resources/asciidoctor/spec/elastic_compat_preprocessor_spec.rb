require 'added/extension'
require 'elastic_compat_preprocessor/extension'
require 'elastic_include_tagged/extension'

RSpec.describe ElasticCompatPreprocessor do
  before(:each) do
    Extensions.register do
      preprocessor ElasticCompatPreprocessor
      include_processor ElasticIncludeTagged
      block_macro AddedBlock
    end
  end

  after(:each) do
    Extensions.unregister_all
  end

  it "invokes added[version]" do
    actual = convert <<~ASCIIDOC
      == Example
      added[some_version]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <note revisionflag="added" revision="some_version">
        <simpara></simpara>
      </note>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "invokes include-tagged::" do
    actual = convert <<~ASCIIDOC
      == Example
      [source,java]
      ----
      include-tagged::resources/elastic_include_tagged/Example.java[t1]
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

  it "doesn't break line numbers" do
    input = <<~ASCIIDOC
      ---
      ---
      <1> callout
    ASCIIDOC
    expect { convert(input) }.to raise_error(
        ConvertError, /<stdin>: line 3: no callout found for <1>/)
  end

  it "doesn't break line numbers in included files" do
    input = <<~ASCIIDOC
      include::resources/elastic_compat_preprocessor/missing_callout.adoc[]
    ASCIIDOC
    expect { convert(input) }.to raise_error(
        ConvertError, /missing_callout.adoc: line 3: no callout found for <1>/)
  end

  it "un-blocks blocks containing only attributes" do
    actual = convert <<~ASCIIDOC
      :inheader: foo

      = Test

      --
      :outheader: bar
      --

      [id="{inheader}-{outheader}"]
      == Header

      <<{inheader}-{outheader}>>
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="foo-bar">
      <title>Header</title>
      <simpara><xref linkend="foo-bar"/></simpara>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "attribute only blocks don't break further processing" do
    actual = convert <<~ASCIIDOC
      :inheader: foo

      = Test

      --
      :outheader: bar
      --

      == Header
      added[some_version]

    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_header">
      <title>Header</title>
      <note revisionflag="added" revision="some_version">
        <simpara></simpara>
      </note>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "attribute only blocks don't pick up blocks without attributes" do
    actual = convert <<~ASCIIDOC
      == Header

      --
      added[some_version]
      --

    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_header">
      <title>Header</title>
      <note revisionflag="added" revision="some_version">
        <simpara></simpara>
      </note>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "attribute only blocks don't pick up blocks with attributes and other stuff" do
    actual = convert <<~ASCIIDOC
      == Header

      --
      :attr: test
      added[some_version]
      --

      [id="{attr}"]
      == Header
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_header">
      <title>Header</title>
      <note revisionflag="added" revision="some_version">
        <simpara></simpara>
      </note>
      </chapter>
      <chapter id="test">
      <title>Header</title>

      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "adds callouts to substitutions for source blocks if there aren't any" do
    actual = convert <<~ASCIIDOC
      == Example
      ["source","sh",subs="attributes"]
      --------------------------------------------
      wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-{version}.zip
      wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-{version}.zip.sha512
      shasum -a 512 -c elasticsearch-{version}.zip.sha512 <1>
      unzip elasticsearch-{version}.zip
      cd elasticsearch-{version}/ <2>
      --------------------------------------------
      <1> Compares the SHA of the downloaded `.zip` archive and the published checksum, which should output
          `elasticsearch-{version}.zip: OK`.
      <2> This directory is known as `$ES_HOME`.
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="sh" linenumbering="unnumbered">wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-{version}.zip
      wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-{version}.zip.sha512
      shasum -a 512 -c elasticsearch-{version}.zip.sha512 <1>
      unzip elasticsearch-{version}.zip
      cd elasticsearch-{version}/ <2></programlisting>
      <calloutlist>
      <callout arearefs="CO1-1">
      <para>Compares the SHA of the downloaded <literal>.zip</literal> archive and the published checksum, which should output
      <literal>elasticsearch-{version}.zip: OK</literal>.</para>
      </callout>
      <callout arearefs="CO1-2">
      <para>This directory is known as <literal>$ES_HOME</literal>.</para>
      </callout>
      </calloutlist>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end
end
