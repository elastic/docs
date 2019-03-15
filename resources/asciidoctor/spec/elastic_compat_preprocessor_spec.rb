# frozen_string_literal: true

require 'care_admonition/extension'
require 'change_admonition/extension'
require 'elastic_compat_preprocessor/extension'
require 'elastic_compat_tree_processor/extension'
require 'elastic_include_tagged/extension'
require 'lang_override/extension'
require 'open_in_widget/extension'
require 'shared_examples/does_not_break_line_numbers'

RSpec.describe ElasticCompatPreprocessor do
  before(:each) do
    Asciidoctor::Extensions.register CareAdmonition
    Asciidoctor::Extensions.register ChangeAdmonition
    Asciidoctor::Extensions.register do
      block_macro LangOverride
      preprocessor ElasticCompatPreprocessor
      include_processor ElasticIncludeTagged
      treeprocessor ElasticCompatTreeProcessor
      treeprocessor OpenInWidget
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  spec_dir = File.dirname(__FILE__)

  include_examples "doesn't break line numbers"

  [
      %w[added added note],
      %w[coming changed note],
      %w[deprecated deleted warning],
  ].each do |(name, revisionflag, tag)|
    it "invokes the #{name} block macro when #{name}[version] starts a line" do
      actual = convert <<~ASCIIDOC
        == Example
        #{name}[some_version]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <#{tag} revisionflag="#{revisionflag}" revision="some_version">
        <simpara></simpara>
        </#{tag}>
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

    it "doesn't mind skipped #{name} block macros" do
      actual = convert <<~ASCIIDOC
        == Example

        ifeval::["true" == "false"]
        #{name}[some_version]
        #endif::[]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>

        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end
  end

  %w[beta experimental].each do |name|
    it "invokes the #{name} block macro when #{name}[] starts a line" do
      actual = convert <<~ASCIIDOC
        == Example
        #{name}[]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <warning role="#{name}">
        <simpara></simpara>
        </warning>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "invokes the #{name} inline macro when #{name}[version] is otherwise on the line" do
      actual = convert <<~ASCIIDOC
        == Example
        words #{name}[]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>words <phrase role="#{name}"/>
        </simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "doesn't mind skipped #{name} block macros" do
      actual = convert <<~ASCIIDOC
        == Example

        ifeval::["true" == "false"]
        #{name}[]
        #endif::[]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>

        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end
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
      shasum -a 512 -c elasticsearch-{version}.zip.sha512 <co id="CO1-1"/>
      unzip elasticsearch-{version}.zip
      cd elasticsearch-{version}/ <co id="CO1-2"/></programlisting>
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

  it "doesn't mind skipped source blocks that are missing callouts" do
    actual = convert <<~ASCIIDOC
      == Example

      ifeval::["true" == "false"]
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
      endif::[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>

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
    actual = convert input, {}, match(/WARN: <stdin>: line 4: MIGRATION: code block end doesn't match start/)
    expect(actual).to eq(expected.strip)
  end

  it "doesn't doesn't mind skipped mismatched code blocks" do
    actual = convert <<~ASCIIDOC
      == Example

      ifeval::["true" == "false"]
      ----
      foo
      --------
      endif::[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>

      </chapter>
    DOCBOOK
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

  def stub_file_opts
    return {
      'copy_snippet' => proc { |uri, source| },
      'write_snippet' => proc { |uri, source| },
    }
  end

  shared_context 'general snippet' do |lang, override|
    let(:snippet) do
      snippet = <<~ASCIIDOC
        [source,js]
        ----
        GET / <1>
        ----
      ASCIIDOC
      snippet += override if override
      snippet
    end
    let(:has_lang) do
      /<programlisting language="#{lang}" linenumbering="unnumbered">/
    end
    let(:input) do
      <<~ASCIIDOC
        == Example
        #{snippet}
      ASCIIDOC
    end
  end
  shared_examples 'linked snippet' do |override, lang, path|
    let(:has_link_to_path) { %r{<ulink type="snippet" url="#{path}"/>} }
    let(:converted) do
      convert input, stub_file_opts, eq(expected_warnings.strip)
    end
    shared_examples 'converted with override' do
      it "has the #{lang} language" do
        expect(converted).to match(has_lang)
      end
      it "have a link to the snippet" do
        expect(converted).to match(has_link_to_path)
      end
    end

    context 'when there is a space after //' do
      include_context 'general snippet', lang, "// #{override}"
      include_examples 'converted with override'
    end
    context 'when there is not a space after //' do
      include_context 'general snippet', lang, "//#{override}"
      include_examples 'converted with override'
    end
    context 'when there is a space after the override command' do
      include_context 'general snippet', lang, "// #{override} "
      include_examples 'converted with override'
    end
  end
  shared_examples 'extracted linked snippet' do |override, lang|
    context "for a snippet with the #{override} lang override" do
      let(:expected_warnings) do
        "INFO: <stdin>: line 3: writing snippet snippets/1.#{lang}"
      end
      include_examples 'linked snippet', override, lang, "snippets/1.#{lang}"
    end
  end
  include_examples 'extracted linked snippet', 'CONSOLE', 'console'
  include_examples 'extracted linked snippet', 'AUTOSENSE', 'sense'
  include_examples 'extracted linked snippet', 'KIBANA', 'kibana'
  context 'for a snippet with the SENSE override pointing to a specific path' do
    let(:expected_warnings) do
      <<~WARNINGS
        INFO: <stdin>: line 3: copying snippet #{spec_dir}/snippets/snippet.sense
        WARN: <stdin>: line 3: reading snippets from a path makes the book harder to read
      WARNINGS
    end
    include_examples(
      'linked snippet',
      'SENSE: snippet.sense',
      'sense',
      'snippets/snippet.sense'
    )
  end
  context 'for a snippet without an override' do
    include_context 'general snippet', 'js', nil
    let(:has_any_link) { /<ulink type="snippet"/ }
    let(:converted) do
      convert input, stub_file_opts
    end

    it "has the js language" do
      expect(converted).to match(has_lang)
    end
    it "not have a link to any snippet" do
      expect(converted).not_to match(has_any_link)
    end
  end
end
