# frozen_string_literal: true

require 'elastic_compat_tree_processor/extension'
require 'lang_override/extension'

RSpec.describe ElasticCompatTreeProcessor do
  before(:each) do
    Asciidoctor::Extensions.register do
      treeprocessor ElasticCompatTreeProcessor
      block_macro LangOverride
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

  shared_examples 'snippet language' do |override, lang|
    name = override ? " the #{override} lang override" : 'out a lang override'
    context "for a snippet with#{name}" do
      let(:snippet) do
        snippet = <<~ASCIIDOC
          [source,js]
          ----
          GET / <1>
          ----
        ASCIIDOC
        snippet += "lang_override::[#{override}]" if override
        snippet
      end
      let(:has_lang) do
        /<programlisting language="#{lang}" linenumbering="unnumbered">/
      end
      shared_examples 'has the expected language' do
        it "has the #{lang} language" do
          expect(converted).to match(has_lang)
        end
      end
      context 'when it is alone' do
        let(:converted) do
          convert <<~ASCIIDOC
            == Example
            #{snippet}
          ASCIIDOC
        end
        include_examples 'has the expected language'
      end
      context 'when it is followed by a paragraph' do
        let(:converted) do
          convert <<~ASCIIDOC
            == Example
            #{snippet}

            Words words words.
          ASCIIDOC
        end
        include_examples 'has the expected language'
        it "the paragraph is intact" do
          expect(converted).to match(%r{<simpara>Words words words.</simpara>})
        end
      end
      context 'when it is inside a definition list' do
        let(:converted) do
          convert <<~ASCIIDOC
            == Example
            Term::
            Definition
            +
            --
            #{snippet}
            --
          ASCIIDOC
        end
        include_examples 'has the expected language'
      end
      context 'when it is followed by a callout list' do
        let(:converted) do
          convert <<~ASCIIDOC
            == Example
            #{snippet}
            <1> foo
          ASCIIDOC
        end
        include_examples 'has the expected language'
        it "has a working callout list" do
          expect(converted).to match(/<callout arearefs="CO1-1">\n<para>foo/)
        end
      end
    end
  end
  include_examples 'snippet language', 'CONSOLE', 'console'
  include_examples 'snippet language', 'AUTOSENSE', 'sense'
  include_examples 'snippet language', 'KIBANA', 'kibana'
  include_examples 'snippet language', 'SENSE:path/to/snippet.sense', 'sense'
  include_examples 'snippet language', nil, 'js'
end
