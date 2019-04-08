# frozen_string_literal: true

require 'change_admonition/extension'

RSpec.describe ChangeAdmonition do
  before(:each) do
    Asciidoctor::Extensions.register ChangeAdmonition
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  shared_context 'change admonition' do
    include_context 'convert without logs'
    context 'block version' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          #{invocation}
        ASCIIDOC
      end
      let(:invocation) { "#{name}::[some_version]" }
      it 'creates the right tag' do
        expect(converted).to include(
          %(<#{tag} revisionflag="#{revisionflag}" revision="some_version">)
        )
      end
      context 'when there is asciidoc in the passtext' do
        let(:invocation) { "#{name}::[some_version,Like 2^7^]" }
        let(:expected) do
          <<~DOCBOOK
            <#{tag} revisionflag="#{revisionflag}" revision="some_version">
            <simpara>Like 2<superscript>7</superscript></simpara>
            </#{tag}>
          DOCBOOK
        end
        it 'renders the asciidoc' do
          expect(converted).to include(expected)
        end
      end
      context 'when written without the ::' do
        let(:invocation) { "#{name}[some_version]" }
        it "isn't invoked" do
          expect(converted).to include("#{name}[some_version]")
        end
      end
    end
    context 'inline version' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          words #{invocation}
        ASCIIDOC
      end
      let(:invocation) { "#{name}:[some_version]" }
      let(:expected) do
        %(<simpara>words ) +
        %(<phrase revisionflag="#{revisionflag}" revision="some_version"/>)
      end
      it 'creates a phrase' do
        expect(converted).to include(expected)
      end
      context 'when extra text is provided' do
        let(:invocation) { "#{name}:[some_version, more words]" }
        let(:expected) do
          <<~DOCBOOK
            <simpara>words <phrase revisionflag="#{revisionflag}" revision="some_version">
              more words
            </phrase>
          DOCBOOK
        end
        it 'adds the text to the phrase' do
          expect(converted).to include(expected)
        end
      end
      context 'when written without the :' do
        let(:invocation) { "#{name}[some_version] " }
        it "isn't invoked" do
          expect(converted).to include(
            "<simpara>words #{name}[some_version]</simpara>"
          )
        end
      end
    end
  end

  context 'for added' do
    let(:name) { 'added' }
    let(:revisionflag) { 'added' }
    let(:tag) { 'note' }
    include_context 'change admonition'
  end
  context 'for coming' do
    let(:name) { 'coming' }
    let(:revisionflag) { 'changed' }
    let(:tag) { 'note' }
    include_context 'change admonition'
  end
  context 'for deprecated' do
    let(:name) { 'deprecated' }
    let(:revisionflag) { 'deleted' }
    let(:tag) { 'warning' }
    include_context 'change admonition'
  end
end
