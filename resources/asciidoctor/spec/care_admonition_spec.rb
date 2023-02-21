# frozen_string_literal: true

require 'care_admonition/extension'

RSpec.describe CareAdmonition do
  before(:each) do
    Asciidoctor::Extensions.register CareAdmonition
    # These can't be rendered without docbook compat at this point.
    Asciidoctor::Extensions.register DocbookCompat
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_context 'convert without logs'

  shared_examples 'care admonition' do
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
      context 'with text' do
        let(:input) do
          <<~ASCIIDOC
            #{key}::[words]
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_block_admonition '<p>words</p>'
        end
      end
      context 'with complex content' do
        let(:input) do
          <<~ASCIIDOC
            #{key}::[See <<some-reference>>]
            [[some-reference]]
            == Some Reference
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_block_admonition <<~HTML.strip
            <p>See <a class="xref" href="#some-reference" title="Some Reference"><em>Some Reference</em></a></p>
          HTML
        end
      end
      context 'without content' do
        let(:input) do
          <<~ASCIIDOC
            #{key}::[]
          ASCIIDOC
        end
        it 'has default text' do
          expect_block_admonition "<p>#{default_text}</p>"
        end
      end
      context 'when written without ::' do
        let(:input) do
          <<~ASCIIDOC
            #{key}[]
          ASCIIDOC
        end
        it "isn't invoked" do
          expect(converted).to include "<p>#{key}[]</p>"
        end
      end
      context 'when only a Github issue link is provided' do
        let(:input) do
          <<~ASCIIDOC
            #{key}::[https://github.com/elastic/docs/issues/505]
          ASCIIDOC
        end
        it 'has default text and github text' do
          expect_block_admonition <<~HTML.strip
            <p>#{default_text} For feature status, see <a href="https://github.com/elastic/docs/issues/505" class="ulink" target="_top">#505</a>.</p>
          HTML
        end
      end
      context 'when only an {issue} link is provided' do
        let(:input) do
          <<~ASCIIDOC
            :issue: https://github.com/elastic/docs/issues/
            #{key}::[{issue}505]
          ASCIIDOC
        end
        it 'has default text and github text' do
          expect_block_admonition <<~HTML.strip
            <p>#{default_text} For feature status, see <a href="https://github.com/elastic/docs/issues/505" class="ulink" target="_top">#505</a>.</p>
          HTML
        end
      end
      context 'when custom text and a Github issue link are provided' do
        let(:input) do
          <<~ASCIIDOC
            #{key}::["Custom text." https://github.com/elastic/docs/issues/505]
          ASCIIDOC
        end
        it 'has custom text and github text' do
          expect_block_admonition <<~HTML.strip
            <p>Custom text. For feature status, see <a href="https://github.com/elastic/docs/issues/505" class="ulink" target="_top">#505</a>.</p>
          HTML
        end
      end
      context 'when custom text and an {issue} link are provided' do
        let(:input) do
          <<~ASCIIDOC
            :issue: https://github.com/elastic/docs/issues/
            #{key}::["Custom text." {issue}505]
          ASCIIDOC
        end
        it 'has custom text and github text' do
          expect_block_admonition <<~HTML.strip
            <p>Custom text. For feature status, see <a href="https://github.com/elastic/docs/issues/505" class="ulink" target="_top">#505</a>.</p>
          HTML
        end
      end
    end
    context 'inline form' do
      def expect_inline_admonition(text)
        expect(converted).to include <<~HTML.strip
          <span class="Admonishment Admonishment--#{key}">
          <span class="Admonishment-title">#{key}</span>
          <span class="Admonishment-detail">
          #{text}
          </span>
          </span>
        HTML
      end
      context 'with text' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}:[admon words] words.
          ASCIIDOC
        end
        it "renders with Elastic's custom template" do
          expect_inline_admonition 'admon words'
        end
      end
      context 'without text' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}:[] words.
          ASCIIDOC
        end
        it 'has default text' do
          expect_inline_admonition default_text
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
            = Title #{key}:[]
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
            expect_inline_admonition default_text
          end
        end
      end
      context 'inside a title' do
        let(:input) do
          <<~ASCIIDOC
            == Foo #{key}:[]
          ASCIIDOC
        end
        it 'has default text' do
          expect_inline_admonition default_text
        end
        it "doesn't modify the id" do
          expect(converted).to include 'id="_foo"'
        end
      end
      context 'inside a floating title' do
        let(:input) do
          <<~ASCIIDOC
            [float]
            == Foo #{key}:[]
          ASCIIDOC
        end
        it 'has default text' do
          expect_inline_admonition default_text
        end
        it "doesn't modify the id" do
          expect(converted).to include 'id="_foo"'
        end
      end
      context 'when written without the :' do
        let(:input) do
          <<~ASCIIDOC
            Words #{key}[] words.
          ASCIIDOC
        end
        it "isn't invoked" do
          expect(converted).to include "<p>Words #{key}[] words.</p>"
        end
      end
    end
  end
  context 'beta' do
    let(:key) { 'beta' }
    let(:admon_class) { 'warning' }
    let(:default_text) do
      <<~TEXT.strip
        This functionality is in beta and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.
      TEXT
    end
    include_examples 'care admonition'
  end
  context 'dev' do
    let(:key) { 'dev' }
    let(:admon_class) { 'warning' }
    let(:default_text) do
      <<~TEXT.strip
        This functionality is in development and may be changed or removed completely in a future release. These features are unsupported and not subject to the support SLA of official GA features.
      TEXT
    end
    include_examples 'care admonition'
  end
  context 'experimental' do
    let(:key) { 'preview' }
    let(:admon_class) { 'warning' }
    let(:default_text) do
      <<~TEXT.strip
        This functionality is in technical preview and may be changed or removed in a future release. Elastic will apply best effort to fix any issues, but features in technical preview are not subject to the support SLA of official GA features.
      TEXT
    end
    include_examples 'care admonition'
  end
  context 'preview' do
    let(:key) { 'preview' }
    let(:admon_class) { 'warning' }
    let(:default_text) do
      <<~TEXT.strip
        This functionality is in technical preview and may be changed or removed in a future release. Elastic will apply best effort to fix any issues, but features in technical preview are not subject to the support SLA of official GA features.
      TEXT
    end
    include_examples 'care admonition'
  end
end
