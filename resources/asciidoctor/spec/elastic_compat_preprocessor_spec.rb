require 'change_admonition/extension'
require 'elastic_compat_preprocessor/extension'
require 'elastic_include_tagged/extension'
require 'shared_examples/does_not_break_line_numbers'

RSpec.describe ElasticCompatPreprocessor do
  before(:each) do
    Extensions.register ChangeAdmonition
    Extensions.register do
      preprocessor ElasticCompatPreprocessor
      include_processor ElasticIncludeTagged
    end
  end

  after(:each) do
    Extensions.unregister_all
  end

  include_examples "doesn't break line numbers"

  [
      %w[added added],
      %w[coming changed],
      %w[deprecated deleted],
  ].each { |(name, revisionflag)|
    it "invokes the #{name} block macro when #{name}[version] starts a line" do
      actual = convert <<~ASCIIDOC
        == Example
        #{name}[some_version]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <note revisionflag="#{revisionflag}" revision="some_version">
        <simpara></simpara>
        </note>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "invokes the #{name} inline macro when #{name}[version] is otherwise on the line" do
      actual = convert <<~ASCIIDOC
        == Example
        words #{name}[some_version]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>words <phrase revisionflag="#{revisionflag}" revision="some_version"/>
        </simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end
  }

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

  it "fixes mismatched fencing on code blocks" do
    input = <<~ASCIIDOC
      == Example
      ----
      foo
      --------
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <screen>foo</screen>
      </chapter>
    DOCBOOK
    actual = convert input, {}, match(/<stdin>: line 4: code block end doesn't match start/)
    expect(actual).to eq(expected.strip)
  end

  it "doesn't break table-style outputs" do
    actual = convert <<~ASCIIDOC
      == Example
      [source,text]
      --------------------------------------------------
          author     |     name      |  page_count   | release_date
      ---------------+---------------+---------------+------------------------
      Dan Simmons    |Hyperion       |482            |1989-05-26T00:00:00.000Z
      Frank Herbert  |Dune           |604            |1965-06-01T00:00:00.000Z
      --------------------------------------------------
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="text" linenumbering="unnumbered">    author     |     name      |  page_count   | release_date
      ---------------+---------------+---------------+------------------------
      Dan Simmons    |Hyperion       |482            |1989-05-26T00:00:00.000Z
      Frank Herbert  |Dune           |604            |1965-06-01T00:00:00.000Z</programlisting>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end
end
