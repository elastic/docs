# frozen_string_literal: true

require 'change_admonition/extension'

RSpec.describe ChangeAdmonition do
  before(:each) do
    Asciidoctor::Extensions.register ChangeAdmonition
    # These can't be rendered without docbook compat at this point.
    Asciidoctor::Extensions.register DocbookCompat
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_context 'convert without logs'

  shared_examples 'change admonition' do
    context 'block form' do
      def expect_block_admonition(body)
        expect(converted).to include <<~HTML
          <div class="#{admon_class} admon">
          <div class="icon"></div>
          <div class="admon_content">
          #{body}
          </div>
          </div>
        HTML
      end
      context 'with content' do
        let(:input) do
          <<~ASCIIDOC
            #{key}::[7.0.0-beta1, words]
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_block_admonition <<~HTML.strip
            <h3>#{message} in 7.0.0-beta1.</h3>
            <p>words</p>
          HTML
        end
      end
      context 'without content' do
        let(:input) do
          <<~ASCIIDOC
            #{key}::[7.0.0-beta1]
          ASCIIDOC
        end
        it 'has default text' do
          expect_block_admonition "<p>#{message} in 7.0.0-beta1.</p>"
        end
      end
      context 'with complex content' do
        let(:input) do
          <<~ASCIIDOC
            #{key}::[7.0.0-beta1, Like 2^7^]
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_block_admonition <<~HTML.strip
            <h3>#{message} in 7.0.0-beta1.</h3>
            <p>Like 2<sup>7</sup></p>
          HTML
        end
      end
      context 'with the ::' do
        let(:input) do
          <<~ASCIIDOC
            #{key}[7.0.0-beta1]
          ASCIIDOC
        end
        it "doesn't render" do
          expect(converted).to include <<~HTML
            <p>#{key}[7.0.0-beta1]</p>
          HTML
        end
      end
    end
    context 'inline form' do
      def expect_inline_admonition(version, text)
        expect(converted).to include <<~HTML.strip
          <span class="Admonishment Admonishment--change">
          <span class="Admonishment-version #{extra_class}">#{version}</span>
          <span class="Admonishment-detail">
          #{text}
          </span>
          </span>
        HTML
      end
      context 'with text' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}:[7.0.0-beta1, admon words] words.
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_inline_admonition(
            '7.0.0-beta1', "#{message} in 7.0.0-beta1. admon words"
          )
        end
      end
      context 'without text' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}:[7.0.0-beta1] words.
          ASCIIDOC
        end
        it 'has default text' do
          expect_inline_admonition(
            '7.0.0-beta1', "#{message} in 7.0.0-beta1."
          )
        end
      end
      context 'inside the document title' do
        let(:standalone) { true }
        let(:convert_attributes) do
          {
            # Shrink the output slightly so it is easier to read
            'stylesheet!' => false,
          }
        end
        let(:input) do
          <<~ASCIIDOC
            = Title #{key}:[7.0.0-beta1]
          ASCIIDOC
        end
        context 'the title' do
          it "doesn't include the admonition" do
            expect(converted).to include '<title>Title | Elastic</title>'
          end
        end
        context 'the heading' do
          it 'includes the admonition' do
            expect(converted).to include <<~HTML.strip
              <h1 class="title"><a id="id-1"></a>Title <span class="Admonishment
            HTML
            # Comment to fix syntax highlighting: ">HTML
          end
          it 'has default text' do
            expect_inline_admonition(
              '7.0.0-beta1', "#{message} in 7.0.0-beta1."
            )
          end
        end
      end
      context 'inside a title' do
        let(:input) do
          <<~ASCIIDOC
            == Foo #{key}:[7.0.0-beta1]
          ASCIIDOC
        end
        it 'has default text' do
          expect_inline_admonition(
            '7.0.0-beta1', "#{message} in 7.0.0-beta1."
          )
        end
        it "doesn't modify the id" do
          expect(converted).to include 'id="_foo"'
        end
      end
      context 'inside a floating title' do
        let(:input) do
          <<~ASCIIDOC
            [float]
            == Foo #{key}:[7.0.0-beta1]
          ASCIIDOC
        end
        it 'has default text' do
          expect_inline_admonition(
            '7.0.0-beta1', "#{message} in 7.0.0-beta1."
          )
        end
        it "doesn't modify the id" do
          expect(converted).to include 'id="_foo"'
        end
      end
      context 'without :' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}[7.0.0-beta1] words.
          ASCIIDOC
        end
        it 'has default text' do
          expect(converted).to include <<~HTML
            <p>Words #{key}[7.0.0-beta1] words.</p>
          HTML
        end
      end
    end
  end
  context 'added' do
    let(:key) { 'added' }
    let(:admon_class) { 'note' }
    let(:message) { 'Added' }
    let(:extra_class) { ' version-added' }
    include_examples 'change admonition'
  end
  context 'coming' do
    let(:key) { 'coming' }
    let(:admon_class) { 'note' }
    let(:message) { 'Coming' }
    let(:extra_class) { ' version-coming' }
    include_examples 'change admonition'
  end
  context 'deprecated' do
    let(:key) { 'deprecated' }
    let(:admon_class) { 'warning' }
    let(:message) { 'Deprecated' }
    let(:extra_class) { ' version-added' }
    include_examples 'change admonition'
  end
end
