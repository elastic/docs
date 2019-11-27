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

        Words.
      ASCIIDOC
    end
    it 'ends in a single newline' do
      expect(converted).to end_with("\n")
      expect(converted).not_to end_with("\n\n")
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
          <div class="titlepage">
          <div>
          <div><h1 class="title"><a id="id-1"></a>Title</h1></div>
          </div>
          <hr>
          </div>
        HTML
      end
    end
    context 'when there is an id on the title' do
      let(:input) do
        <<~ASCIIDOC
          [[title-id]]
          = Title

          Words.
        ASCIIDOC
      end
      context 'the header' do
        it "is wrapped in docbook's funny titlepage" do
          expect(converted).to include(<<~HTML)
            <div class="titlepage">
            <div>
            <div><h1 class="title"><a id="title-id"></a>Title</h1></div>
            </div>
            <hr>
            </div>
          HTML
        end
      end
    end
    context 'when there is a table of contents' do
      let(:convert_attributes) do
        {
          # Shrink the output slightly so it is easier to read
          'stylesheet!' => false,
          # Set some metadata that will be included in the header
          'dc.type' => 'FooType',
          'dc.subject' => 'BarSubject',
          'dc.identifier' => 'BazIdentifier',
          'toc' => '',
          'toclevels' => 1,
        }
      end
      let(:input) do
        <<~ASCIIDOC
          = Title

          == Section 1

          == Section 2
        ASCIIDOC
      end
      context 'the header' do
        it "is wrapped in docbook's funny titlepage" do
          expect(converted).to include(<<~HTML)
            <div class="titlepage">
            <div>
            <div><h1 class="title"><a id="id-1"></a>Title</h1></div>
            </div>
            <hr>
          HTML
        end
      end
      context 'the table of contents' do
        it 'is outside the titlepage' do
          expect(converted).to include(<<~HTML)
            <hr>
            </div>
            <div id="content">
            <!--START_TOC-->
            <div class="toc">
          HTML
        end
        it 'looks like the docbook toc' do
          expect(converted).to include(<<~HTML)
            <!--START_TOC-->
            <div class="toc">
            <ul class="toc">
            <li><span class="chapter"><a href="#_section_1">Section 1</a></span>
            </li>
            <li><span class="chapter"><a href="#_section_2">Section 2</a></span>
            </li>
            </ul>
            </div>
            <!--END_TOC-->
          HTML
        end
      end
      context 'when there is a level 0 section' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            = Part 1

            == Section 1

            == Section 2
          ASCIIDOC
        end
        context 'the table of contents' do
          it 'looks like the docbook toc' do
            expect(converted).to include(<<~HTML)
              <!--START_TOC-->
              <div class="toc">
              <ul class="toc">
              <li><span class="part"><a href="#_part_1">Part 1</a></span>
              <ul>
              <li><span class="chapter"><a href="#_section_1">Section 1</a></span>
              </li>
              <li><span class="chapter"><a href="#_section_2">Section 2</a></span>
              </li>
              </ul>
              </li>
              </ul>
              </div>
              <!--END_TOC-->
            HTML
          end
        end
      end
    end
    context 'when there is a subtitle' do
      let(:input) do
        <<~ASCIIDOC
          = Title: Subtitle

          Words.
        ASCIIDOC
      end
      context 'the title' do
        it "doesn't include the subtitle" do
          expect(converted).to include('<title>Title | Elastic</title>')
        end
      end
      context 'the header' do
        it 'includes the title and subtitle' do
          expect(converted).to include(<<~HTML)
            <div class="titlepage">
            <div>
            <div><h1 class="title"><a id="id-1"></a>Title</h1></div>
            <div><h2 class="subtitle">Subtitle</h2></div>
            </div>
            <hr>
            </div>
          HTML
        end
      end
    end
    context 'contains a navheader' do
      # Emulates the chunker without trying to include it.
      let(:input) do
        <<~ASCIIDOC
          = Title: Subtitle

          [pass]
          --
          <div class="navheader">
          nav nav nav
          </div>
          --

          Words.
        ASCIIDOC
      end
      context 'the navheader' do
        it 'is moved above the "book" wrapper' do
          expect(converted).to include(<<~HTML)
            <div class="navheader">
            nav nav nav
            </div>
            <div class="book" lang="en">
          HTML
        end
      end
    end
    context 'contains a navfooer' do
      # Emulates the chunker without trying to include it.
      let(:input) do
        <<~ASCIIDOC
          = Title: Subtitle

          [pass]
          --
          <div class="navfooter">
          nav nav nav
          </div>
          --

          Words.
        ASCIIDOC
      end
      context 'the navfooter' do
        it 'is moved below the "book" wrapper' do
          expect(converted).to include(<<~HTML)
            <div class="navfooter">
            nav nav nav
            </div>
            </body>
          HTML
        end
      end
    end
    context 'when the head is disabled' do
      let(:convert_attributes) do
        {
          # Shrink the output slightly so it is easier to read
          'stylesheet!' => false,
          # Set some metadata that will be included in the header
          'dc.type' => 'FooType',
          'dc.subject' => 'BarSubject',
          'dc.identifier' => 'BazIdentifier',
          # Disable the head
          'noheader' => true,
        }
      end
      let(:input) do
        <<~ASCIIDOC
          = Title

          Words.
        ASCIIDOC
      end
      context 'the header' do
        it "doesn't contain the title h1" do
          expect(converted).not_to include('Title</h1>')
        end
      end
      context 'the body' do
        it "doesn't have attributes" do
          expect(converted).to include('<body>')
        end
        it "doesn't include the 'book' wrapper" do
          expect(converted).not_to include(<<~HTML)
            <div class="book" lang="en">
          HTML
        end
      end
    end
  end

  context 'sections' do
    shared_examples 'section basics' do |wrapper_class, hlevel, id, title|
      context 'the wrapper' do
        it "has the '#{wrapper_class}' class" do
          expect(converted).to include(<<~HTML.strip)
            <div class="#{wrapper_class}">
          HTML
        end
      end
      context 'the header' do
        it "is wrapped in docbook's funny titlepage" do
          expect(converted).to include(<<~HTML)
            <div class="titlepage"><div><div>
            <h#{hlevel} class="title"><a id="#{id}"></a>#{title}</h#{hlevel}>
            </div></div></div>
          HTML
        end
      end
    end

    context 'level 1' do
      let(:input) do
        <<~ASCIIDOC
          == Section
        ASCIIDOC
      end
      include_examples 'section basics', 'chapter', 1, '_section', 'Section'
    end

    context 'level 2' do
      let(:input) do
        <<~ASCIIDOC
          === Section 2
        ASCIIDOC
      end
      include_examples 'section basics', 'section', 2, '_section_2', 'Section 2'
    end

    context 'a preface' do
      let(:input) do
        <<~ASCIIDOC
          [preface]
          == Preface
          Words.
        ASCIIDOC
      end
      include_examples 'section basics', 'preface', 1, '_preface', 'Preface'
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
    context 'when the link is to an inline anchor' do
      let(:input) do
        <<~ASCIIDOC
          [[target]]`target`:: foo

          <<target>>
        ASCIIDOC
      end
      it 'references the url' do
        expect(converted).to include('href="#target"')
      end
      it 'has the right title' do
        expect(converted).to include('><code class="literal">target</code></a>')
      end
    end
  end

  context 'a cross reference' do
    let(:input) do
      <<~ASCIIDOC
        Words <<foo>>.

        [[foo]]
        == Foo
      ASCIIDOC
    end
    it 'has xref class' do
      expect(converted).to include('class="xref"')
    end
    it 'references the target' do
      expect(converted).to include('href="#foo"')
    end
    it "contains the target's title" do
      expect(converted).to include('title="Foo"')
    end
    it 'wraps the title in <em>' do
      expect(converted).to include('><em>Foo</em></a>')
    end
  end

  context 'a floating title' do
    let(:input) do
      <<~ASCIIDOC
        [float]
        ==== Foo
      ASCIIDOC
    end
    it 'has the right h level' do
      expect(converted).to include('<h4>')
    end
    it 'has an inline anchor for docbook compatibility' do
      expect(converted).to include('<a id="_foo"></a>')
    end
  end

  context 'a listing block' do
    let(:input) do
      <<~ASCIIDOC
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

    context 'paired with a callout list' do
      let(:input) do
        <<~ASCIIDOC
          [source,sh]
          ----
          cpanm Search::Elasticsearch <1>
          ----
          <1> Foo
        ASCIIDOC
      end
      context 'the listing' do
        it 'includes the callout' do
          expect(converted).to include <<~HTML.strip
            cpanm Search::Elasticsearch <a id="CO1-1"></a><i class="conum" data-value="1"></i>
          HTML
        end
      end
      context 'the callout list' do
        it 'is rendered like a docbook callout list' do
          expect(converted).to include <<~HTML
            <div class="calloutlist">
            <table border="0" summary="Callout list">
            <tr>
            <td align="left" valign="top" width="5%">
            <p><a href="#CO1-1"><i class="conum" data-value="1"></i></a></p>
            </td>
            <td align="left" valign="top">
            <p>Foo</p>
            </td>
            </tr>
            </table>
            </div>
          HTML
        end
      end
    end
  end

  context 'an unordered list' do
    let(:input) do
      <<~ASCIIDOC
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
  context 'an ordered list' do
    let(:input) do
      <<~ASCIIDOC
        . Thing
        . Other thing
        . Third thing
      ASCIIDOC
    end
    it 'is wrapped an orderedlist div' do
      expect(converted).to include('<div class="olist orderedlist">')
    end
    it 'has the itemizedlist class' do
      expect(converted).to include('<ol class="orderedlist"')
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
        Words `backticked`.
      ASCIIDOC
    end
    it 'is considered a "literal" by default' do
      expect(converted).to include('<code class="literal">backticked</code>')
    end
  end

  context 'stronged text' do
    let(:input) do
      <<~ASCIIDOC
        *strong words*
      ASCIIDOC
    end
    it 'is rendered like docbook' do
      expect(converted).to include(<<~HTML.strip)
        <span class="strong strong"><strong>strong words</strong></span>
      HTML
    end
  end

  context 'admonitions' do
    shared_examples 'standard admonition' do |key, admonclass|
      let(:input) do
        <<~ASCIIDOC
          #{key}: words
        ASCIIDOC
      end
      it "renders with Elastic's custom template" do
        expect(converted).to include(<<~HTML)
          <div class="#{admonclass} admon">
          <div class="icon"></div>
          <div class="admon_content">
          <p>
          words
          </p>
          </div>
          </div>
        HTML
      end
    end
    context 'note' do
      include_examples 'standard admonition', 'NOTE', 'note'
    end
    context 'tip' do
      include_examples 'standard admonition', 'TIP', 'tip'
    end
    context 'important' do
      include_examples 'standard admonition', 'IMPORTANT', 'important'
    end
    context 'caution' do
      include_examples 'standard admonition', 'CAUTION', 'caution'
    end
    context 'warning' do
      include_examples 'standard admonition', 'WARNING', 'warning'
    end
  end

  context 'a literal' do
    let(:input) do
      <<~ASCIIDOC
        Words

            Literal words
              indented literal words

        Words
      ASCIIDOC
    end
    it 'renders like docbook' do
      expect(converted).to include(<<~HTML)
        <pre class="literallayout">Literal words
          indented literal words</pre>
      HTML
    end
  end

  context 'a sidebar' do
    let(:input) do
      <<~ASCIIDOC
        .Title
        ****
        Words
        ****
      ASCIIDOC
    end
    it 'renders like docbook' do
      expect(converted).to include(<<~HTML)
        <div class="sidebar">
        <div class="titlepage"><div><div>
        <p class="title"><strong>Title</strong></p>
        </div></div></div>
        <p>Words</p>

        </div>
      HTML
    end
  end
end
