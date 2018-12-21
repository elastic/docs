require 'elastic_compat_tree_processor/extension'

RSpec.describe ElasticCompatTreeProcessor do
  before(:each) do
    Extensions.register do
      treeprocessor ElasticCompatTreeProcessor
    end
  end

  after(:each) do
    Extensions.unregister_all
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
end
