# frozen_string_literal: true

require 'care_admonition/extension'

RSpec.describe CareAdmonition do
  before(:each) do
    Asciidoctor::Extensions.register CareAdmonition
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  %w[beta experimental].each do |(name)|
    it "#{name}'s block version creates a warning" do
      actual = convert <<~ASCIIDOC
        == Example
        #{name}::[]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <warning role="#{name}">
        <simpara></simpara>
        </warning>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "#{name}'s block version supports asciidoc in the passtext" do
      actual = convert <<~ASCIIDOC
        == Example
        #{name}::[See <<some-reference>>]
        [[some-reference]]
        === Some Reference
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <warning role="#{name}">
        <simpara>See <xref linkend="some-reference"/></simpara>
        </warning>
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
        #{name}[]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>#{name}[]</simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "#{name}'s inline version creates a phrase" do
      actual = convert <<~ASCIIDOC
        == Example
        words #{name}:[]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>words <phrase role="#{name}"/>
        </simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end

    it "#{name}'s inline version creates a phrase with extra text if provided" do
      actual = convert <<~ASCIIDOC
        == Example
        words #{name}:[more words]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>words <phrase role="#{name}">
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
        words #{name}[]
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <simpara>words #{name}[]</simpara>
        </chapter>
      DOCBOOK
      expect(actual).to eq(expected.strip)
    end
  end
end
