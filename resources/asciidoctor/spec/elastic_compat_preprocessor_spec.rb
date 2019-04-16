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

  context 'admonitions' do
    shared_examples 'admonition' do
      include_context 'convert without logs'

      shared_examples 'invokes the block macro' do
        let(:expected) do
          <<~DOCBOOK
            <#{tag_start}>
            <simpara></simpara>
            </#{tag_end}>
          DOCBOOK
        end
        it 'invokes the block macro' do
          expect(converted).to include(expected)
        end
      end
      context 'when the admonition is alone on a line' do
        let(:input) { invocation }
        include_examples 'invokes the block macro'
      end
      context 'when the admonition has spaces before it' do
        let(:input) { "   #{invocation}" }
        include_examples 'invokes the block macro'
      end
      context 'when the admonition has spaces after it' do
        let(:input) { "#{invocation}   " }
        include_examples 'invokes the block macro'
      end
      context 'when the admonition has a `]` in it' do
        let(:invocation_text) { 'link:link.html[Title]' }
        let(:input) { invocation_with_text }
        include_examples 'invokes the block macro'
        let(:expected) do
          <<~DOCBOOK
            <#{tag_start}>
            <simpara><ulink url="link.html">Title</ulink></simpara>
            </#{tag_end}>
          DOCBOOK
        end
      end

      shared_examples 'invokes the inline macro' do
        it 'invokes the inline macro' do
          expect(converted).to include("<phrase #{phrase}/>")
        end
      end
      context "when the admonition is surrounded by other text" do
        let(:input) { "words #{invocation} words" }
        include_examples 'invokes the inline macro'
      end
      context "when the admonition has text before it" do
        let(:input) { "words #{invocation}" }
        include_examples 'invokes the inline macro'
      end
      context "when the admonition has text after it" do
        let(:input) { "#{invocation} words" }
        include_examples 'invokes the inline macro'
      end

      context 'when the admonition is skipped' do
        let(:input) do
          <<~ASCIIDOC
            words before skip
            ifeval::["true" == "false"]
            #{invocation}
            endif::[]
            words after skip
          ASCIIDOC
        end
        it 'skips the admonition' do
          expect(converted).not_to include('revisionflag')
        end
        it 'properly converts the rest of the text' do
          expect(converted).to include('words before skip')
          expect(converted).to include('words after skip')
        end
      end
    end

    shared_examples 'change admonition' do
      include_examples 'admonition'
      let(:invocation) { "#{name}[some_version]" }
      let(:invocation_with_text) { "#{name}[some_version, #{invocation_text}]" }
      let(:tag_start) do
        %(#{tag} revisionflag="#{revisionflag}" revision="some_version")
      end
      let(:tag_end) { tag }
      let(:phrase) { %(revisionflag="#{revisionflag}" revision="some_version") }
    end
    context 'for added' do
      include_context 'change admonition'
      let(:name) { 'added' }
      let(:revisionflag) { 'added' }
      let(:tag) { 'note' }
    end
    context 'for coming' do
      include_context 'change admonition'
      let(:name) { 'coming' }
      let(:revisionflag) { 'changed' }
      let(:tag) { 'note' }
    end
    context 'for added' do
      include_context 'change admonition'
      let(:name) { 'deprecated' }
      let(:revisionflag) { 'deleted' }
      let(:tag) { 'warning' }
    end

    shared_examples 'care admonition' do
      include_examples 'admonition'
      let(:invocation) { "#{name}[]" }
      let(:invocation_with_text) { "#{name}[#{invocation_text}]" }
      let(:tag_start) { %(warning role="#{name}") }
      let(:tag_end) { 'warning' }
      let(:phrase) { %(role="#{name}") }
    end
    context 'for beta' do
      include_context 'care admonition'
      let(:name) { 'beta' }
    end
    context 'for experimental' do
      include_context 'care admonition'
      let(:name) { 'experimental' }
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
