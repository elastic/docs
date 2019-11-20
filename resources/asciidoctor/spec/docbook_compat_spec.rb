# frozen_string_literal: true

require 'docbook_compat/extension'
require 'fileutils'
require 'tmpdir'

RSpec.describe DocbookCompat do
  before(:each) do
    Asciidoctor::Extensions.register DocbookCompat
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_context 'convert without logs'
  let(:backend) { :html5 }

  context 'the header and footer' do
    let(:standalone) { true }
    let(:convert_attributes) do
      {
        # Shrink the output slightly so it is easier to read
        'stylesheet!' => false,
        # Set some metadata that will be included in the header
        'dc.type' => 'FooType',
        'dc.subject' => 'BarSubject',
        'dc.identifier' => 'BazIdentifier',
      }
    end
    let(:input) do
      <<~ASCIIDOC
        = Title

        [[section]]
        == Section
      ASCIIDOC
    end
    it 'has an empty html tag' do
      expect(converted).to include('<html>')
    end
    it "doesn't declare edge compatibility" do
      expect(converted).not_to include('content="IE=edge"')
    end
    it "doesn't declare a viewport" do
      expect(converted).not_to include('name="viewport"')
    end
    it "doesn't declare a generator" do
      expect(converted).not_to include('name="generator"')
    end
    it 'has DC.type' do
      expect(converted).to include(<<~HTML)
        <meta name="DC.type" content="FooType"/>
      HTML
    end
    it 'has DC.subject' do
      expect(converted).to include(<<~HTML)
        <meta name="DC.subject" content="BarSubject"/>
      HTML
    end
    it 'has DC.identifier' do
      expect(converted).to include(<<~HTML)
        <meta name="DC.identifier" content="BazIdentifier"/>
      HTML
    end
    context 'the title' do
      it 'includes Elastic' do
        expect(converted).to include('<title>Title | Elastic</title>')
      end
    end
    context 'the body' do
      it "doesn't have attributes" do
        expect(converted).to include('<body>')
      end
      it 'is immediately followed by wrappers' do
        expect(converted).to include(<<~HTML)
          <body>
          <div class="book" lang="en">
        HTML
      end
    end
    context 'the header' do
      it "is wrapped in docbook's funny titlepage" do
        expect(converted).to include(<<~HTML)
          <div class="titlepage"><div><div>
          <h1 class="title"><a id="id-1"></a>Title</h1>
          </div></div><hr></div>
        HTML
      end
    end
  end

  context 'a level 1 section' do
    let(:input) do
      <<~ASCIIDOC
        = Title

        [[section]]
        == Section
      ASCIIDOC
    end
    context 'the wrapper' do
      it 'has the "chapter" class' do
        expect(converted).to include '<div class="chapter">'
      end
    end
    context 'the header' do
      it "is wrapped in docbook's funny titlepage" do
        expect(converted).to include(<<~HTML)
          <div class="titlepage"><div><div>
          <h1 class="title"><a id="section"></a>Section</h1>
          </div></div></div>
        HTML
      end
    end
  end

  context 'a level 2 section' do
    let(:input) do
      <<~ASCIIDOC
        = Title

        == Section 1

        [[section-2]]
        === Section 2
      ASCIIDOC
    end
    context 'the wrapper' do
      it 'has the "chapter" class' do
        expect(converted).to include '<div class="section">'
      end
    end
    context 'the header' do
      it "is wrapped in docbook's funny titlepage" do
        expect(converted).to include(<<~HTML)
          <div class="titlepage"><div><div>
          <h2 class="title"><a id="section-2"></a>Section 2</h2>
          </div></div></div>
        HTML
      end
    end
  end

  context 'a paragraph' do
    let(:input) do
      <<~ASCIIDOC
        = Title

        == Section
        Words words words.
      ASCIIDOC
    end
    it "isn't wrapped in a paragraph div" do
      expect(converted).not_to include('<div class="paragraph">')
    end
    it 'contains the words' do
      expect(converted).to include('<p>Words words words.</p>')
    end
  end

  context 'a link' do
    let(:input) do
      <<~ASCIIDOC
        = Title

        == Section

        Words #{link}.
      ASCIIDOC
    end
    let(:url) { 'https://metacpan.org/module/Search::Elasticsearch' }
    let(:link) { url }
    it 'has ulink class' do
      expect(converted).to include('class="ulink"')
    end
    it 'targets the _top' do
      expect(converted).to include('target="_top"')
    end
    it 'references the url' do
      expect(converted).to include(<<~HTML.strip)
        href="#{url}"
      HTML
    end
    it 'contains the link text' do
      expect(converted).to include(">#{url}</a>")
    end
    context 'when the link text and window is overridden' do
      let(:link) { "#{url}[docs,window=_blank]" }
      it 'contains the overridden text' do
        expect(converted).to include('>docs</a>')
      end
      it 'targets the overridden window' do
        expect(converted).to include('target="_blank"')
      end
    end
  end

  context 'a listing block' do
    let(:input) do
      <<~ASCIIDOC
        = Title

        == Section
        [source,sh]
        ----
        cpanm Search::Elasticsearch
        ----
      ASCIIDOC
    end
    it "is wrapped in docbook's funny wrapper" do
      # It is important that there isn't any extra space around the <pre> tags
      expect(converted).to include(<<~HTML)
        <div class="pre_wrapper lang-sh">
        <pre class="programlisting prettyprint lang-sh">cpanm Search::Elasticsearch</pre>
        </div>
      HTML
    end
  end

  context 'an unordered list' do
    let(:input) do
      <<~ASCIIDOC
        = Title

        == Section
        * Thing
        * Other thing
        * Third thing
      ASCIIDOC
    end
    it 'is wrapped an itemizedlist div' do
      expect(converted).to include('<div class="ulist itemizedlist">')
    end
    it 'has the itemizedlist class' do
      expect(converted).to include('<ul class="itemizedlist"')
    end
    context 'the first item' do
      it 'has the listitem class' do
        expect(converted).to include(<<~HTML)
          <li class="listitem">
          Thing
          </li>
        HTML
      end
    end
    context 'the second item' do
      it 'has the listitem class' do
        expect(converted).to include(<<~HTML)
          <li class="listitem">
          Other thing
          </li>
        HTML
      end
    end
    context 'the third item' do
      it 'has the listitem class' do
        expect(converted).to include(<<~HTML)
          <li class="listitem">
          Third thing
          </li>
        HTML
      end
    end
  end

  context 'backticked code' do
    let(:input) do
      <<~ASCIIDOC
        = Title

        == Section
        Words `backticked`.
      ASCIIDOC
    end
    it 'is considered a "literal" by default' do
      expect(converted).to include('<code class="literal">backticked</code>')
    end
  end
end
