# frozen_string_literal: true

require 'cramped_include/extension'
require 'elastic_compat_preprocessor/extension'
require 'shared_examples/does_not_break_line_numbers'

RSpec.describe CrampedInclude do
  before(:each) do
    Asciidoctor::Extensions.register do
      preprocessor CrampedInclude
      preprocessor ElasticCompatPreprocessor
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_examples "doesn't break line numbers"

  it "allows cramped includes of callout lists" do
    actual = convert <<~ASCIIDOC
      = Test

      == Test

      include::resources/cramped_include/colist1.adoc[]
      include::resources/cramped_include/colist2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_test">
      <title>Test</title>
      <section id="P1">
      <title>P1</title>
      <section id="P1_1">
      <title>P1.1</title>
      <programlisting language="java" linenumbering="unnumbered">words <1> <2></programlisting>
      <calloutlist>
      <callout arearefs="CO1-1">
      <para>foo</para>
      </callout>
      </calloutlist>
      </section>
      </section>
      <section id="P2">
      <title>P2</title>
      <section id="P2_1">
      <title>P2.1</title>
      <programlisting language="java" linenumbering="unnumbered">words <1> <2></programlisting>
      <calloutlist>
      <callout arearefs="CO2-1">
      <para>foo</para>
      </callout>
      </calloutlist>
      </section>
      </section>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "doesn't break includes of non-asciidoc files" do
    actual = convert <<~ASCIIDOC
      ----
      include::resources/cramped_include/Example.java[]
      ----
    ASCIIDOC
    expected = <<~DOCBOOK
      <preface>
      <title></title>
      <screen>public class Example {}</screen>
      </preface>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end
end
