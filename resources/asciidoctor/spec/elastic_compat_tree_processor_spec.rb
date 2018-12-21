require 'elastic_compat_tree_processor/extension'

RSpec.describe ElasticCompatPreprocessor do
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
      ["source","java",subs="attributes,callouts,macros,verbatim"]
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
      <programlisting language="java" linenumbering="unnumbered">System.err.println("I'm an example");
      for (int i = 0; i < 10; i++) {
          System.err.println(i); <1>
      }</programlisting>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end
end
