# frozen_string_literal: true

require 'care_admonition/extension'

RSpec.describe CareAdmonition do
  before(:each) do
    Asciidoctor::Extensions.register CareAdmonition
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  shared_context 'care admonition' do
    include_context 'convert without logs'
    context 'block version' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          #{name}::[]
        ASCIIDOC
      end
      it 'creates a warning' do
        expect(converted).to include <<~DOCBOOK
          <warning role="#{name}">
          <simpara>#{default_text}</simpara>
          </warning>
        DOCBOOK
      end
      context 'when there is asciidoc in the passtext' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            #{name}::[See <<some-reference>>]
            [[some-reference]]
            === Some Reference
          ASCIIDOC
        end
        let(:expected) do
          <<~DOCBOOK
            <warning role="#{name}">
            <simpara>See <xref linkend="some-reference"/></simpara>
            </warning>
          DOCBOOK
        end
        it 'renders the asciidoc' do
          expect(converted).to include(expected)
        end
      end
      context 'when written without the ::' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            #{name}[]
          ASCIIDOC
        end
        it "isn't invoked" do
          expect(converted).to include("<simpara>#{name}[]</simpara>")
        end
      end
    end
    context 'inline version' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          words #{name}:[]
        ASCIIDOC
      end
      let(:expected) { "<simpara>words <phrase role=\"#{name}\"/>" }
      it 'creates a phrase' do
        expect(converted).to include(expected)
      end
      context 'when there is extra text' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            words #{name}:[more words]
          ASCIIDOC
        end
        let(:expected) do
          <<~ASCIIDOC
            <simpara>words <phrase role="#{name}">
              more words
            </phrase>
            </simpara>
          ASCIIDOC
        end
        it 'creates a phrase with the extra' do
          expect(converted).to include(expected)
        end
      end
      context 'when written without the :' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            words #{name}[]
          ASCIIDOC
        end
        it "isn't invoked" do
          expect(converted).to include("<simpara>words #{name}[]</simpara>")
        end
      end
    end
  end

  context 'for beta' do
    let(:name) { 'beta' }
    let(:default_text) do
      <<~TEXT.strip
        This functionality is in beta and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.
      TEXT
    end
    include_context 'care admonition'
  end
  context 'for experimental' do
    let(:name) { 'experimental' }
    let(:default_text) do
      <<~TEXT.strip
        This functionality is experimental and may be changed or removed completely in a future release. Elastic will take a best effort approach to fix any issues, but experimental features are not subject to the support SLA of official GA features.
      TEXT
    end
    include_context 'care admonition'
  end
end
