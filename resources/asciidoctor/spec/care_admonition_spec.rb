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
    include_context 'convert no logs'
    context 'block version' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          #{name}::[]
        ASCIIDOC
      end
      let(:expected) do
        <<~DOCBOOK
          <warning role="#{name}">
          <simpara></simpara>
          </warning>
        DOCBOOK
      end
      it 'creates a warning' do
        expect(converted).to include(expected)
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
      context "when written without the ::" do
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
    include_context 'care admonition'
  end
  context 'for experimental' do
    let(:name) { 'experimental' }
    include_context 'care admonition'
  end
end
