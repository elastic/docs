require 'added/extension'

RSpec.describe Added do
  before(:each) do
    Extensions.register Added
  end

  after(:each) do
    Extensions.unregister_all
  end

  it "block version creates a note" do
    actual = convert <<~ASCIIDOC
      == Example
      added::[some_version]
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

  it "block version is not invoked without the ::" do
    actual = convert <<~ASCIIDOC
      == Example
      added[some_version]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <simpara>added[some_version]</simpara>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "inline version creates a phrase" do
    actual = convert <<~ASCIIDOC
      == Example
      words added:[some_version]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <simpara>words <phrase revisionflag="added" revision="some_version"/>
      </simpara>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "inline version creates a phrase with extra text if provided" do
    actual = convert <<~ASCIIDOC
      == Example
      words added:[some_version, more words]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <simpara>words <phrase revisionflag="added" revision="some_version">
        more words
      </phrase>
      </simpara>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

  it "inline version is not invoked without the :" do
    actual = convert <<~ASCIIDOC
      == Example
      words added[some_version]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <simpara>words added[some_version]</simpara>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end
end
