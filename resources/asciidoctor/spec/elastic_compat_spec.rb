require 'added/extension'
require 'elastic_compat/extension'

RSpec.describe ElasticCompatPreprocessor do
  before(:each) do
    Extensions.register do
      # preprocessor ElasticCompatPreprocessor
      block_macro AddedBlock
    end
  end

  after(:each) do
    Extensions.unregister_all
  end

  it "invokes added without the ::" do
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

  it "doesn't break line numbers" do
    input = <<~ASCIIDOC
      ---
      ---
      <1> callout
    ASCIIDOC
    expect { convert(input) }.to raise_error(
        ConvertError, /line 3: no callout found for <1>/)
  end

  it "doesn't break line numbers in included files" do
    input = <<~ASCIIDOC
      include::resources/elastic_compat/missing_callout.adoc[]
    ASCIIDOC
    expect { puts convert(input) }.to raise_error(
        ConvertError, /line 4: no callout found for <1>/)
  end

end

Extensions.unregister_all
