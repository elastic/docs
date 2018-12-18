require 'added/extension'
require 'elastic_compat/extension'

RSpec.describe AddedBlock do
  before(:each) do
    Extensions.register do
      preprocessor ElasticCompatPreprocessor
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
      <section id="_example">
      <title>Example</title>
      <note revisionflag="added" revision="some_version">
        <simpara></simpara>
      </note>
      </section>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end
end

Extensions.unregister_all
