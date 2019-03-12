# frozen_string_literal: true

require 'elastic_compat_tree_processor/extension'

RSpec.describe ElasticCompatTreeProcessor do
  before(:each) do
    Asciidoctor::Extensions.register do
      treeprocessor ElasticCompatTreeProcessor
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  it "fixes up asciidoc style listings" do
    actual = convert <<~ASCIIDOC
      == Example
      ["source","java",subs="attributes,callouts,macros"]
      --------------------------------------------------
      long count = response.count(); <1>
      List<CategoryDefinition> categories = response.categories(); <2>
      --------------------------------------------------
      <1> The count of categories that were matched
      <2> The categories retrieved
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="java" linenumbering="unnumbered">long count = response.count(); <co id="CO1-1"/>
      List&lt;CategoryDefinition&gt; categories = response.categories(); <co id="CO1-2"/></programlisting>
      <calloutlist>
      <callout arearefs="CO1-1">
      <para>The count of categories that were matched</para>
      </callout>
      <callout arearefs="CO1-2">
      <para>The categories retrieved</para>
      </callout>
      </calloutlist>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "doesn't mind missing definitions" do
    actual = convert <<~ASCIIDOC
      == Example
      `thing1`::

        def1

      `thing2`::
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <variablelist>
      <varlistentry>
      <term><literal>thing1</literal></term>
      <listitem>
      <simpara>def1</simpara>
      </listitem>
      </varlistentry>
      <varlistentry>
      <term><literal>thing2</literal></term>
      <listitem>
      </listitem>
      </varlistentry>
      </variablelist>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  [
    %w[CONSOLE console],
    %w[AUTOSENSE sense],
    %w[KIBANA kibana],
    %w[SENSE:path/to/snippet.sense sense],
  ].each do |command, lang|
    it "transforms legacy // #{command} commands into the #{lang} language" do
      actual = convert <<~ASCIIDOC
        == Example
        [source,js]
        ----
        GET /
        ----
        pass:[// #{command}]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <programlisting language="#{lang}" linenumbering="unnumbered">GET /</programlisting>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end
  end

  context 'a snippet is inside of a definition list' do
    let(:result) do
      convert <<~ASCIIDOC
        == Example
        Term::
        Definition
        +
        --
        [source,js]
        ----
        GET /
        ----
        --
      ASCIIDOC
    end
    let(:has_original_language) do
      match %r{<programlisting language="js" linenumbering="unnumbered">GET /</programlisting>}
    end
    it "doesn't break" do
      expect(result).to has_original_language
    end
  end
end
