require 'change_admonishment/extension'

RSpec.describe ChangeAdmonishment do
  before(:each) do
    Extensions.register ChangeAdmonishment
  end

  after(:each) do
    Extensions.unregister_all
  end

  [
      ['added', 'added'],
      ['coming', 'changed'],
      ['deprecated', 'deleted']
  ].each { |(name, revisionflag)|
    it "#{name}'s block version creates a note" do
      actual = convert <<~ASCIIDOC
        == Example
        #{name}::[some_version]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <note revisionflag="#{revisionflag}" revision="some_version">
        <simpara></simpara>
        </note>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "#{name}'s block version supports asciidoc in the passtext" do
    actual = convert <<~ASCIIDOC
      == Example
      #{name}::[some_version,See <<some-reference>>]
      [[some-reference]]
      === Some Reference
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <note revisionflag="#{revisionflag}" revision="some_version">
      <simpara>See <xref linkend="some-reference"/></simpara>
      </note>
      <section id="some-reference">
      <title>Some Reference</title>

      </section>
      </chapter>
    DOCBOOK
    expect(actual).to eq(expected.strip)
  end

    it "#{name}'s block version is not invoked without the ::" do
      actual = convert <<~ASCIIDOC
        == Example
        #{name}[some_version]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>#{name}[some_version]</simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "#{name}'s inline version creates a phrase" do
      actual = convert <<~ASCIIDOC
        == Example
        words #{name}:[some_version]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>words <phrase revisionflag="#{revisionflag}" revision="some_version"/>
        </simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "#{name}'s inline version creates a phrase with extra text if provided" do
      actual = convert <<~ASCIIDOC
        == Example
        words #{name}:[some_version, more words]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>words <phrase revisionflag="#{revisionflag}" revision="some_version">
          more words
        </phrase>
        </simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "#{name}'s inline version is not invoked without the :" do
      actual = convert <<~ASCIIDOC
        == Example
        words #{name}[some_version]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>words #{name}[some_version]</simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end
  }
end
