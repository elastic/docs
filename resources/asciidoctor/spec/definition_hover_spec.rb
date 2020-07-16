# frozen_string_literal: true

require 'definition_hover/extension'

RSpec.describe ChangeAdmonition do
  before(:each) do
    Asciidoctor::Extensions.register DefinitionAdmonition
    # These can't be rendered without docbook compat at this point.
    Asciidoctor::Extensions.register DocbookCompat
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_context 'convert without logs'

  shared_examples 'definition pop-up' do
    context 'inline form' do
      def expect_definition_popup(word, definition)
        expect(converted).to include <<~HTML.strip
          <span class="Definition Definition--definition" aria-describedby="Definition-defined">
          <span class="Definition-word">#{word}</span>
          <span class="Definition-defined">
          #{definition}
          </span>
          </span>
        HTML
      end
      context 'with text' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}:[#{word},#{definition}] words.
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_definition_popup(
            "#{word}", "#{definition}"
          )
        end
      end
      context 'with a comma' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}:[#{word},"#{definition} , comma"] words.
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_definition_popup(
            "#{word}", "#{definition} , comma"
          )
        end
      end
      context 'without definition' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}:[#{word},] words.
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_definition_popup(
            "#{word}", ''
          )
        end
      end
      context 'without :' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}[#{word},#{definition}] words.
          ASCIIDOC
        end
        it 'has default text' do
          expect(converted).to include <<~HTML
            <p>Words #{key}[#{word},#{definition}] words.</p>
          HTML
        end
      end
    end
  end
  context 'definition' do
    let(:key) { 'definition' }
    let(:word) { 'run' }
    let(:definition) { 'To move at a speed faster than a walk' }
    include_examples 'definition pop-up'
  end
end