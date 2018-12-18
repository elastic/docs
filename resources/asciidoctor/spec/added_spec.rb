require 'added/extension'

RSpec.describe AddedBlock do
  before(:each) do
    Extensions.register do
      block_macro AddedBlock
    end
  end

  after(:each) do
    Extensions.unregister_all
  end

  it "creates a note" do
    actual = convert <<~ASCIIDOC
      == Example
      added::[some_version]
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

  it "is not invoked without the ::" do
    actual = convert <<~ASCIIDOC
      == Example
      added[some_version]
    ASCIIDOC
    expected = <<~DOCBOOK
      <section id="_example">
      <title>Example</title>
      <simpara>added[some_version]</simpara>
      </section>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end
end
