# frozen_string_literal: true

require 'care_admonition/extension'
require 'change_admonition/extension'
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
        'docdir' => '/doc/observability-docs/docs/en/observability',
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
    it 'has an elastic meta product_name tag' do
      expect(converted).to include(<<~HTML)
        <meta class="elastic" name="product_name" content="BarSubject"/>
      HTML
    end
    it 'has an elastic meta product_version tag' do
      expect(converted).to include(<<~HTML)
        <meta class="elastic" name="product_version" content="BazIdentifier"/>
      HTML
    end
    it 'has an elastic meta website_area tag' do
      expect(converted).to include(<<~HTML)
        <meta class="elastic" name="website_area" content="documentation"/>
      HTML
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
    it "doesn't contain a directive to not follow or index the page" do
      expect(converted).not_to include(
        '<meta name="robots" content="noindex,nofollow"/>'
      )
    end
    context 'the title' do
      it 'includes Elastic' do
        expect(converted).to include(<<~HTML)
          <title>Title | Elastic</title>
          <meta class="elastic" name="content" content="Title">
        HTML
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
          <!--EXTRA-->
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
            <!--EXTRA-->
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
            <!--EXTRA-->
          HTML
        end
      end
      context 'the table of contents' do
        it 'is outside the titlepage' do
          expect(converted).to include(<<~HTML)
            <hr>
            <!--EXTRA-->
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
      context 'when a section has role=exclude' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            == Section 1

            [.exclude]
            == Section 2
          ASCIIDOC
        end
        context 'the table of contents' do
          it "doesn't include the excluded section" do
            expect(converted).to include(<<~HTML)
              <!--START_TOC-->
              <div class="toc">
              <ul class="toc">
              <li><span class="chapter"><a href="#_section_1">Section 1</a></span>
              </li>
              </ul>
              </div>
              <!--END_TOC-->
            HTML
          end
        end
      end
      context 'when a section has reftext' do
        let(:convert_attributes) do
          {
            # Shrink the output slightly so it is easier to read
            'stylesheet!' => false,
            # Set some metadata that will be included in the header
            'dc.type' => 'FooType',
            'dc.subject' => 'BarSubject',
            'dc.identifier' => 'BazIdentifier',
            'toc' => '',
            'toclevels' => 2,
          }
        end
        shared_examples 'reftext' do
          context 'the table of contents' do
            it 'includes the abbreviated title' do
              expect(converted).to include <<~HTML
                <li><span class="chapter"><a href="#s1">S1</a></span>
              HTML
            end
            it 'includes the correct title for a subsection' do
              expect(converted).to include <<~HTML
                <li><span class="section"><a href="#_section_2">Section 2</a></span>
              HTML
            end
          end
          context 'the body' do
            it "doesn't include the titleabbrev tag" do
              expect(converted).not_to include '<titleabbrev>'
            end
            it 'includes the unabbreviated title' do
              expect(converted).to include 'Section 1</h1>'
            end
            it 'includes a link to the abbreviated section' do
              expect(converted).to include <<~HTML.strip
                <a class="xref" href="#s1" title="Section 1"><em>S1</em></a>
              HTML
            end
          end
        end
        context 'using a pass block containing titleabbrev' do
          let(:input) do
            <<~ASCIIDOC
              = Title

              [[s1]]
              == Section 1
              ++++
              <titleabbrev>S1</titleabbrev>
              ++++

              === Section 2

              <<s1>>
            ASCIIDOC
          end
          include_examples 'reftext'
          context 'when the titleabbrev contains an attribute' do
            let(:input) do
              <<~ASCIIDOC
                = Title

                :abbrev: S1
                [[s1]]
                == Section 1
                ++++
                <titleabbrev>{abbrev}</titleabbrev>
                ++++

                === Section 2

                <<s1>>
              ASCIIDOC
            end
            include_examples 'reftext'
          end
        end
        context 'using an attribute' do
          let(:input) do
            <<~ASCIIDOC
              = Title

              [id=s1,reftext=_S1_]
              == Section 1

              === Section 2

              <<s1>>
            ASCIIDOC
          end
          include_examples 'reftext'
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
          expect(converted).to include(<<~HTML)
            <title>Title | Elastic</title>
            <meta class="elastic" name="content" content="Title">
          HTML
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
            <!--EXTRA-->
            </div>
          HTML
        end
      end
    end
    context 'when there is markup in the title' do
      let(:input) do
        <<~ASCIIDOC
          = `foo`

          Words.
        ASCIIDOC
      end
      context 'the title' do
        it 'only includes the text of the title' do
          expect(converted).to include(<<~HTML)
            <title>foo | Elastic</title>
            <meta class="elastic" name="content" content="foo">
          HTML
        end
      end
      context 'the header' do
        it 'includes the title and subtitle' do
          expect(converted).to include(<<~HTML)
            <div class="titlepage">
            <div>
            <div><h1 class="title"><a id="id-1"></a><code class="literal">foo</code></h1></div>
            </div>
            <hr>
            <!--EXTRA-->
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
    context 'when there is a page-header' do
      let(:convert_attributes) do
        {
          # Shrink the output slightly so it is easier to read
          'stylesheet!' => false,
          'page-header' => '<div class="foo" />',
        }
      end
      let(:input) do
        <<~ASCIIDOC
          = Title

          Words.
        ASCIIDOC
      end
      context 'the header' do
        it 'contains the page-header right after the body tag' do
          expect(converted).not_to include <<~HTML
            <body>
            <div class="foo" />
          HTML
        end
      end
    end
    context 'when the head is disabled' do
      let(:convert_attributes) do
        {
          # Shrink the output slightly so it is easier to read
          'stylesheet!' => false,
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

      context 'when there is a page-header' do
        let(:convert_attributes) do
          {
            # Shrink the output slightly so it is easier to read
            'stylesheet!' => false,
            'noheader' => true,
            'page-header' => '<div class="foo" />',
          }
        end
        let(:input) do
          <<~ASCIIDOC
            = Title

            Words.
          ASCIIDOC
        end
        context 'the header' do
          it 'contains the page-header right after the body tag' do
            expect(converted).not_to include <<~HTML
              <body>
              <div class="foo" />
            HTML
          end
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
          # Turn off indexing
          'noindex' => true,
        }
      end
      let(:input) do
        <<~ASCIIDOC
          = Title

          Words.
        ASCIIDOC
      end
      context 'the head' do
        it 'contains a directive to not follow or index the page' do
          expect(converted).to include(
            '<meta name="robots" content="noindex,nofollow"/>'
          )
        end
      end
    end
    context 'when there is title-extra' do
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
          'title-extra' => ' [fooo]',
        }
      end
      let(:input) do
        <<~ASCIIDOC
          = Title

          == Section 1

          == Section 2
        ASCIIDOC
      end
      context 'the title' do
        it 'includes Elastic' do
          expect(converted).to include(<<~HTML)
            <title>Title [fooo] | Elastic</title>
            <meta class="elastic" name="content" content="Title [fooo]">
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
        let(:xpack_tag) do
          if (input.include? '.xpack') &&
             (!input.include? ':hide-xpack-tags: true')
            '<a class="xpack_tag" href="/subscriptions"></a>'
          else
            ''
          end
        end
        it "is wrapped in docbook's funny titlepage" do
          expect(converted).to include(<<~HTML)
            <div class="titlepage"><div><div>
            <h#{hlevel} class="title"><a id="#{id}"></a>#{title}#{xpack_tag}</h#{hlevel}>
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
      context 'with the xpack role' do
        let(:input) do
          <<~ASCIIDOC
            [.xpack]
            == S1
          ASCIIDOC
        end
        include_examples 'section basics', 'chapter xpack', 1, '_s1', 'S1'
        context 'with the hide-xpack-tags attribute' do
          let(:input) do
            <<~ASCIIDOC
              :hide-xpack-tags: true

              [.xpack]
              == Some XPack Feature
            ASCIIDOC
          end
          # Because the block is marked with the `xpack` role, the surrounding
          # <div> will still have the "xpack" class. But the clickable icon
          # should be hidden.
          include_examples 'section basics', 'chapter xpack', 1,
                           '_some_xpack_feature', 'Some XPack Feature'
        end
      end
    end

    context 'level 2' do
      let(:input) do
        <<~ASCIIDOC
          === Section 2
        ASCIIDOC
      end
      include_examples 'section basics', 'section', 2, '_section_2', 'Section 2'
      context 'with the xpack role' do
        let(:input) do
          <<~ASCIIDOC
            [.xpack]
            === S2
          ASCIIDOC
        end
        include_examples 'section basics', 'section xpack', 2, '_s2', 'S2'
      end
    end

    context 'level 3' do
      let(:input) do
        <<~ASCIIDOC
          ==== Section 3
        ASCIIDOC
      end
      include_examples 'section basics', 'section', 3, '_section_3', 'Section 3'
      context 'with the xpack role' do
        let(:input) do
          <<~ASCIIDOC
            [.xpack]
            ==== S3
          ASCIIDOC
        end
        include_examples 'section basics', 'section xpack', 3, '_s3', 'S3'
      end
    end

    context 'level 0' do
      let(:input) do
        <<~ASCIIDOC
          = Title

          = Section

          == L1

          === L2
        ASCIIDOC
      end
      include_examples 'section basics', 'part', 1, '_section', 'Section'
      it "bumps the h tag of it's children" do
        expect(converted).to include 'L1</h2>'
      end
      it "doesn't bump the h tag of it's children's children" do
        # Docbook doesn't seem to do this
        expect(converted).to include 'L2</h2>'
      end
      context 'with the xpack role' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [.xpack]
            = S1

            == Chapter
          ASCIIDOC
        end
        include_examples 'section basics', 'part xpack', 1, '_s1', 'S1'
      end
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
      context 'with the xpack role' do
        let(:input) do
          <<~ASCIIDOC
            [preface.xpack]
            == P
          ASCIIDOC
        end
        include_examples 'section basics', 'preface xpack', 1, '_p', 'P'
      end
    end

    context 'an appendix' do
      let(:input) do
        <<~ASCIIDOC
          [appendix]
          == Foo
          Words.
        ASCIIDOC
      end
      include_examples 'section basics', 'appendix', 1, '_foo',
                       'Appendix A: Foo'
      context 'with the xpack role' do
        let(:input) do
          <<~ASCIIDOC
            [appendix.xpack]
            == Foo
          ASCIIDOC
        end
        include_examples 'section basics', 'appendix xpack', 1, '_foo',
                         'Appendix A: Foo'
      end
      context 'with level 0' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [appendix]
            = Foo

            == Bar
          ASCIIDOC
        end
        include_examples 'section basics', 'appendix', 1, '_foo',
                         'Appendix A: Foo'
        it "doesn't bump the h tags of sections within it" do
          expect(converted).to include 'Bar</h1>'
        end
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
    context 'has an id' do
      let(:input) do
        <<~ASCIIDOC
          [[foo]]
          Words.
        ASCIIDOC
      end
      it 'contains the id' do
        expect(converted).to include '<p><a id="foo"></a>Words.</p>'
      end
    end
    context 'with a title' do
      let(:input) do
        <<~ASCIIDOC
          .Title
          Words.
        ASCIIDOC
      end
      it 'contains the title' do
        expect(converted).to include '<p><strong>Title</strong>Words.</p>'
      end
    end
    context 'with a role' do
      let(:input) do
        <<~ASCIIDOC
          [.screenshot]
          image:foo[]
        ASCIIDOC
      end
      it 'has the role as a class' do
        expect(converted).to include <<~HTML
          <p class="screenshot"><span class="image"><img src="foo" alt="foo"></span></p>
        HTML
      end
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
      expect(converted).to include(' class="xref"')
    end
    it 'references the target' do
      expect(converted).to include(' href="#foo"')
    end
    it "contains the target's title" do
      expect(converted).to include(' title="Foo"')
    end
    it 'wraps the title in <em>' do
      expect(converted).to include('><em>Foo</em></a>')
    end

    context 'when the link text is overridden' do
      let(:input) do
        <<~ASCIIDOC
          Words <<foo,override text>>.

          [[foo]]
          == Foo
        ASCIIDOC
      end
      it 'contains the overridden text' do
        expect(converted).to include('>override text</a>')
      end
    end
    context 'when the section title has markup' do
      let(:input) do
        <<~ASCIIDOC
          Words <<foo>>.

          [[foo]]
          == `foo`
        ASCIIDOC
      end
      it "contains the target's title without the markup" do
        expect(converted).to include('title="foo"')
      end
    end
    context 'when the section title is empty' do
      let(:input) do
        <<~ASCIIDOC
          Words <<foo>>.

          [[foo]]
          ==
        ASCIIDOC
      end
      it "doesn't contain a title at all" do
        expect(converted).not_to include('title')
      end
    end
    context 'to an inline anchor' do
      let(:input) do
        <<~ASCIIDOC
          [[target]]`target`:: foo

          <<target>>
        ASCIIDOC
      end
      it 'references the url' do
        expect(converted).to include('href="#target"')
      end
      it 'has the right text' do
        expect(converted).to include('><code class="literal">target</code></a>')
      end

      context 'when that inline anchor has empty text' do
        let(:input) do
          <<~ASCIIDOC
            == Section heading

            Words.
            [[target]]
            more words.

            <<target>>
          ASCIIDOC
        end
        it 'references the url' do
          expect(converted).to include('href="#target"')
        end
        it 'has the right text' do
          expect(converted).to include('>Section heading</a>')
        end
      end
    end
    context 'to an appendix' do
      let(:input) do
        <<~ASCIIDOC
          <<target>>

          [[target]]
          [appendix]
          == Foo
        ASCIIDOC
      end
      it 'references the url' do
        expect(converted).to include('href="#target"')
      end
      it 'has the right text' do
        expect(converted).to include('>Appendix A, <em>Foo</em></a>')
      end
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

    context 'with the xpack role' do
      let(:input) do
        <<~ASCIIDOC
          [float.xpack]
          ==== Foo
        ASCIIDOC
      end
      it 'has the xpack class' do
        expect(converted).to include '<h4 class="xpack">'
      end
      it 'has the xpack tag' do
        expect(converted).to include(
          '<a class="xpack_tag" href="/subscriptions"></a></h4>'
        )
      end
    end
    context 'with the xpack bug is declared inline' do
      let(:input) do
        <<~ASCIIDOC
          [float]
          ==== [xpack]#Foo#
        ASCIIDOC
      end
      it 'has the xpack tag' do
        expect(converted).to include <<~HTML
          <span class="xpack">Foo</span><a class="xpack_tag" href="/subscriptions"></a></h4>
        HTML
      end
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
        <div class="console_code_copy" title="Copy to clipboard"></div>
        <pre class="programlisting prettyprint lang-sh">cpanm Search::Elasticsearch</pre>
        </div>
      HTML
    end
    it "isn't followed by an extra blank line" do
      expect(converted).to include(<<~HTML)
        </pre>
        </div>
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

      context 'that has a role' do
        let(:input) do
          <<~ASCIIDOC
            [source,sh]
            ----
            cpanm Search::Elasticsearch <1>
            ----
            [.foo]
            <1> Foo
          ASCIIDOC
        end
        context 'the callout list' do
          it 'includes the role' do
            expect(converted).to include '<div class="calloutlist foo">'
          end
        end
      end
      context 'that has duplicates' do
        let(:input) do
          <<~ASCIIDOC
            [source,sh]
            ----
            foo <1>
            bar <1>
            baz <2>
            ----
            <1> Foo
            <2> Baz
          ASCIIDOC
        end
        context 'the duplicated callouts in the listing' do
          it 'have the same data-value' do
            expect(converted).to include <<~HTML
              foo <a id="CO1-1"></a><i class="conum" data-value="1"></i>
              bar <a id="CO1-2"></a><i class="conum" data-value="1"></i>
            HTML
          end
        end
        context 'the unique callout in the listing' do
          it 'has a number that counts up from the previously shown number' do
            expect(converted).to include <<~HTML
              baz <a id="CO1-3"></a><i class="conum" data-value="2"></i></pre>
            HTML
          end
        end
        context 'the duplicated callouts in the callout list' do
          it 'only contains a single number' do
            expect(converted).to include <<~HTML
              <p><a href="#CO1-1"><i class="conum" data-value="1"></i></a><a href="#CO1-2"></a></p>
            HTML
          end
        end
        context 'the unique callout in the callout list' do
          it 'has a number that counts up from the previously shown number' do
            expect(converted).to include <<~HTML
              <p><a href="#CO1-3"><i class="conum" data-value="2"></i></a></p>
            HTML
          end
        end
      end
    end
    context 'with a title' do
      let(:input) do
        <<~ASCIIDOC
          .Title
          [source,sh]
          ----
          cpanm Search::Elasticsearch
          ----
        ASCIIDOC
      end
      it "the title is before in docbook's funny wrapper" do
        expect(converted).to include(<<~HTML)
          <p><strong>Title.</strong></p>
          <div class="pre_wrapper lang-sh">
        HTML
      end

      context 'that ends in a :' do
        let(:input) do
          <<~ASCIIDOC
            .Title:
            [source,sh]
            ----
            cpanm Search::Elasticsearch
            ----
          ASCIIDOC
        end
        it "the title is before in docbook's funny wrapper" do
          expect(converted).to include(<<~HTML)
            <p><strong>Title:</strong></p>
            <div class="pre_wrapper lang-sh">
          HTML
        end
      end
    end
    context 'with an id' do
      let(:input) do
        <<~ASCIIDOC
          [source,sh,id=foo]
          ----
          cpanm Search::Elasticsearch
          ----
        ASCIIDOC
      end
      it "the title is before in docbook's funny wrapper" do
        expect(converted).to include(<<~HTML)
          <a id="foo"></a><div class="pre_wrapper lang-sh">
        HTML
      end
    end
    context 'with an id and a title' do
      let(:input) do
        <<~ASCIIDOC
          .Title
          [source,sh,id=foo]
          ----
          cpanm Search::Elasticsearch
          ----
        ASCIIDOC
      end
      it "the title is before in docbook's funny wrapper" do
        expect(converted).to include(<<~HTML)
          <p><a id="foo"></a><strong>Title.</strong></p>
          <div class="pre_wrapper lang-sh">
        HTML
      end
    end
    context 'with a role' do
      let(:input) do
        <<~ASCIIDOC
          [source,sh,role=foo]
          ----
          cpanm Search::Elasticsearch
          ----
        ASCIIDOC
      end
      it 'the role is included as a class' do
        expect(converted).to include(<<~HTML)
          <div class="pre_wrapper lang-sh foo">
          <div class="console_code_copy" title="Copy to clipboard"></div>
          <pre class="programlisting prettyprint lang-sh foo">cpanm Search::Elasticsearch</pre>
          </div>
        HTML
      end
    end
    context "when the listing doesn't have a language" do
      let(:input) do
        <<~ASCIIDOC
          ----
          cpanm Search::Elasticsearch
          ----
        ASCIIDOC
      end
      it "is wrapped in docbook's funny wrapper" do
        # It is important that there isn't any extra space around the <pre> tags
        expect(converted).to include(<<~HTML)
          <pre class="screen">cpanm Search::Elasticsearch</pre>
        HTML
      end
      it "isn't followed by an extra blank line" do
        expect(converted).to include(<<~HTML)
          </pre>
          </div>
        HTML
      end
      context 'with a title' do
        let(:input) do
          <<~ASCIIDOC
            .Title
            ----
            cpanm Search::Elasticsearch
            ----
          ASCIIDOC
        end
        it "the title is before in docbook's funny wrapper" do
          expect(converted).to include(<<~HTML)
            <p><strong>Title.</strong></p>
            <pre class="screen">cpanm Search::Elasticsearch</pre>
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

    context 'when there is a title' do
      let(:input) do
        <<~ASCIIDOC
          .Title
          * Thing
        ASCIIDOC
      end
      context 'the title' do
        it 'is wrapped a strong' do
          expect(converted).to include <<~HTML
            <div class="ulist itemizedlist">
            <p class="title"><strong>Title</strong></p>
          HTML
        end
      end
    end
    context 'when it is a TODO list' do
      context "when it isn't done" do
        let(:input) do
          <<~ASCIIDOC
            * [ ] Thing
          ASCIIDOC
        end
        it 'includes to empty check box' do
          expect(converted).to include <<~HTML
            <div class="ulist checklist itemizedlist">
            <ul class="checklist">
            <li class="listitem">
            &#10063; Thing
            </li>
            </ul>
            </div>
          HTML
        end
      end
      context 'when it is done' do
        let(:input) do
          <<~ASCIIDOC
            * [x] Thing
          ASCIIDOC
        end
        it 'includes the check mark' do
          expect(converted).to include <<~HTML
            <div class="ulist checklist itemizedlist">
            <ul class="checklist">
            <li class="listitem">
            &#10003; Thing
            </li>
            </ul>
            </div>
          HTML
        end
      end
      context 'when it is interactive' do
        context "when it isn't done" do
          let(:input) do
            <<~ASCIIDOC
              [%interactive]
              * [ ] Thing
            ASCIIDOC
          end
          it 'includes to empty check box' do
            expect(converted).to include <<~HTML
              <div class="ulist checklist itemizedlist">
              <ul class="checklist">
              <li class="listitem">
              <input type="checkbox" data-item-complete="0"> Thing
              </li>
              </ul>
              </div>
            HTML
          end
        end
        context 'when it is done' do
          let(:input) do
            <<~ASCIIDOC
              [%interactive]
              * [x] Thing
            ASCIIDOC
          end
          it 'includes the check mark' do
            expect(converted).to include <<~HTML
              <div class="ulist checklist itemizedlist">
              <ul class="checklist">
              <li class="listitem">
              <input type="checkbox" data-item-complete="1" checked> Thing
              </li>
              </ul>
              </div>
            HTML
          end
        end
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

    context 'when there is a title' do
      let(:input) do
        <<~ASCIIDOC
          .Title
          . Thing
        ASCIIDOC
      end
      context 'the title' do
        it 'is wrapped a strong' do
          expect(converted).to include <<~HTML
            <div class="olist orderedlist">
            <p class="title"><strong>Title</strong></p>
          HTML
        end
      end
    end
    context 'when the list if defined with 1.' do
      let(:input) do
        <<~ASCIIDOC
          1. Thing
        ASCIIDOC
      end
      it 'is wrapped an orderedlist div' do
        expect(converted).to include('<div class="olist orderedlist">')
      end
      it 'has the itemizedlist class' do
        expect(converted).to include('<ol class="orderedlist"')
      end
      context 'the item' do
        it 'has the listitem class' do
          expect(converted).to include(<<~HTML)
            <li class="listitem">
            Thing
            </li>
          HTML
        end
      end
    end
    context 'with complex contents' do
      let(:input) do
        <<~ASCIIDOC
          . Foo
          +
          --
          Complex
          --
        ASCIIDOC
      end
      it 'wraps the text in a <p>' do
        expect(converted).to include(<<~HTML)
          <li class="listitem">
          <p>Foo</p>
        HTML
      end
      it 'includes the complex content' do
        expect(converted).to include(<<~HTML)
          <p>Complex</p>
          </li>
        HTML
      end
    end
    context 'second level' do
      let(:input) do
        <<~ASCIIDOC
          . L1
          .. L2
          .. Thing 2
        ASCIIDOC
      end
      it 'the outer list is wrapped an orderedlist div' do
        expect(converted).to include <<~HTML
          <div class="sectionbody">
          <div class="olist orderedlist">
          <ol class="orderedlist">
        HTML
      end
      it 'the inner list is wrapped an orderedlist div' do
        expect(converted).to include <<~HTML
          <p>L1</p>
          <div class="olist orderedlist">
          <ol class="orderedlist">
        HTML
      end
    end
  end

  context 'a description list' do
    context 'basic' do
      let(:input) do
        <<~ASCIIDOC
          Foo:: The foo.
          [[bar]] Bar:: The bar.
        ASCIIDOC
      end
      it 'is wrapped like docbook' do
        expect(converted).to include <<~HTML
          <div class="variablelist">
          <dl class="variablelist">
        HTML
        expect(converted).to include <<~HTML
          </dl>
          </div>
        HTML
      end
      it 'contains the first item' do
        expect(converted).to include <<~HTML
          <dt>
          <span class="term">
          Foo
          </span>
          </dt>
          <dd>
          The foo.
          </dd>
        HTML
      end
      it 'contains the second item' do
        expect(converted).to include <<~HTML
          <dt>
          <span class="term">
          <a id="bar"></a> Bar
          </span>
          </dt>
          <dd>
          The bar.
          </dd>
        HTML
      end
    end

    context 'without a descrition' do
      let(:input) do
        <<~ASCIIDOC
          Foo::
        ASCIIDOC
      end
      it "doesn't have a dd" do
        expect(converted).not_to include '<dd>'
      end
    end
    context 'with complex content' do
      let(:input) do
        <<~ASCIIDOC
          Foo::
          +
          --
          Lots of content.

          In many paragraphs.
          --
        ASCIIDOC
      end
      it 'contains complex content' do
        expect(converted).to include <<~HTML
          <dt>
          <span class="term">
          Foo
          </span>
          </dt>
          <dd>
          <p>Lots of content.</p>
          <p>In many paragraphs.</p>
          </dd>
        HTML
      end
    end
    context 'when the anchor is on the previous line' do
      let(:input) do
        <<~ASCIIDOC
          [[bar]]
          Bar:: The bar.
        ASCIIDOC
      end
      it 'the id preceeds dl' do
        expect(converted).to include <<~HTML
          <div class="variablelist">
          <a id="bar"></a>
          <dl class="variablelist">
        HTML
      end
    end
    context 'horizontally styled' do
      let(:input) do
        <<~ASCIIDOC
          [horizontal]
          Foo:: The foo.
          Bar:: The bar.
        ASCIIDOC
      end
      it 'is rendered like a table' do
        expect(converted).to include <<~HTML
          <div class="informaltable">
          <table border="0" cellpadding="4px">
          <colgroup>
          <col/>
          <col/>
          </colgroup>
          <tbody valign="top">
        HTML
        expect(converted).to include <<~HTML
          </tbody>
          </table>
          </div>
        HTML
      end
      it 'contains a row for the first entry' do
        expect(converted).to include <<~HTML
          <tr>
          <td valign="top">
          <p>
          Foo
          </p>
          </td>
          <td valign="top">
          <p>
          The foo.
          </p>
          </td>
          </tr>
        HTML
      end
      it 'contains a row for the second entry' do
        expect(converted).to include <<~HTML
          <tr>
          <td valign="top">
          <p>
          Bar
          </p>
          </td>
          <td valign="top">
          <p>
          The bar.
          </p>
          </td>
          </tr>
        HTML
      end

      context 'when it has a title' do
        let(:input) do
          <<~ASCIIDOC
            .Title
            [horizontal]
            Foo:: The foo.
            Bar:: The bar.
          ASCIIDOC
        end
        it 'has the title in a strong' do
          expect(converted).to include <<~HTML
            <div class="table">
            <p class="title"><strong>Table 1. Title</strong></p>
            <div class="table-contents">
          HTML
        end
        it 'has the title as the summary' do
          expect(converted).to include <<~HTML
            <div class="table-contents">
            <table border="0" cellpadding="4px" summary="Title">
          HTML
        end

        context 'when the title has markup in it' do
          let(:input) do
            <<~ASCIIDOC
              .`foo`
              [horizontal]
              Foo:: The foo.
              Bar:: The bar.
            ASCIIDOC
          end
          it 'has the title in a strong with the html' do
            expect(converted).to include <<~HTML
              <div class="table">
              <p class="title"><strong>Table 1. <code class="literal">foo</code></strong></p>
              <div class="table-contents">
            HTML
          end
          it 'has the title as the summary without the html' do
            expect(converted).to include <<~HTML
              <div class="table-contents">
              <table border="0" cellpadding="4px" summary="foo">
            HTML
          end
        end
      end
    end
    context 'question and anwer styled' do
      let(:input) do
        <<~ASCIIDOC
          [qanda]
          What is foo?:: You don't want to know.
          Who is Baz?:: Baz is Baz.
        ASCIIDOC
      end
      it 'is rendered like a table' do
        expect(converted).to include <<~HTML
          <div class="qandaset">
          <table border="0">
          <colgroup>
          <col align="left" width="1%"/>
          <col/>
          </colgroup>
          <tbody>
        HTML
        expect(converted).to include <<~HTML
          </tbody>
          </table>
          </div>
        HTML
      end
      it 'contains a row for the first entry' do
        expect(converted).to include <<~HTML
          <tr class="question">
          <td align="left" valign="top">
          <p><strong>1.</strong></p>
          </td>
          <td align="left" valign="top">
          <p>
          What is foo?
          </p>
          </td>
          </tr>
          <tr class="answer">
          <td align="left" valign="top">
          </td>
          <td align="left" valign="top">
          <p>
          You don&#8217;t want to know.
          </p>
          </td>
          </tr>
        HTML
      end
      it 'contains a row for the second entry' do
        expect(converted).to include <<~HTML
          <tr class="question">
          <td align="left" valign="top">
          <p><strong>2.</strong></p>
          </td>
          <td align="left" valign="top">
          <p>
          Who is Baz?
          </p>
          </td>
          </tr>
          <tr class="answer">
          <td align="left" valign="top">
          </td>
          <td align="left" valign="top">
          <p>
          Baz is Baz.
          </p>
          </td>
          </tr>
        HTML
      end
    end
    context 'glossary styled' do
      let(:input) do
        <<~ASCIIDOC
          [glossary]
          Foo:: The foo.
          Bar:: The bar.
        ASCIIDOC
      end
      it 'is wrapped in a dl' do
        expect(converted).to include '<dl>'
        expect(converted).to include '</dl>'
      end
      it 'contains a dt/dd pair for the first entry' do
        expect(converted).to include <<~HTML
          <dt>
          <span class="glossterm">
          Foo
          </span>
          </dt>
          <dd class="glossdef">
          The foo.
          </dd>
        HTML
      end
      it 'contains a dt/dd pair for the second entry' do
        expect(converted).to include <<~HTML
          <dt>
          <span class="glossterm">
          Bar
          </span>
          </dt>
          <dd class="glossdef">
          The bar.
          </dd>
        HTML
      end
    end
    context 'an unimplemented dlist style' do
      include_context 'convert with logs'
      let(:input) do
        <<~ASCIIDOC
          [not_implemented]
          Foo:: The foo.
          Bar:: The bar.
        ASCIIDOC
      end
      it 'logs an warning' do
        expect(logs).to eq <<~LOG.strip
          WARN: <stdin>: line 2: Can't convert unknown description list style [not_implemented].
        LOG
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
    context 'built in admonitions' do
      shared_examples 'standard admonition' do
        context 'with text' do
          let(:input) do
            <<~ASCIIDOC
              #{key}: words
            ASCIIDOC
          end
          it "renders with Elastic's custom template" do
            expect_block_admonition '<p>words</p>'
          end
        end
        context 'with complex content' do
          let(:input) do
            <<~ASCIIDOC
              [#{key}]
              --
              . words
              --
            ASCIIDOC
          end
          it 'contains the complex content' do
            expect_block_admonition <<~HTML.strip
              <div class="olist orderedlist">
              <ol class="orderedlist">
              <li class="listitem">
              words
              </li>
              </ol>
              </div>
            HTML
          end
        end
        context 'without content' do
          let(:input) do
            <<~ASCIIDOC
              [#{key}]
              --
              --
            ASCIIDOC
          end
          it "doesn't have default text" do
            expect_block_admonition '<p></p>'
          end
        end
        context 'with a title' do
          let(:input) do
            <<~ASCIIDOC
              [#{key}]
              .Title
              --
              words
              --
            ASCIIDOC
          end
          it "renders the title in Elastic's custom template" do
            expect(converted).to include(<<~HTML)
              <div class="#{admon_class} admon">
              <div class="icon"></div>
              <div class="admon_content">
              <h3>Title</h3>
              <p>words</p>
              </div>
              </div>
            HTML
          end

          context 'and an id' do
            let(:input) do
              <<~ASCIIDOC
                [[id]]
                [#{key}]
                .Title
                --
                words
                --
              ASCIIDOC
            end
            it "renders the title in Elastic's custom template" do
              expect(converted).to include(<<~HTML)
                <div class="#{admon_class} admon">
                <div class="icon"></div>
                <div class="admon_content">
                <h3>Title<a id="id"></a></h3>
                <p>words</p>
                </div>
                </div>
              HTML
            end
          end
        end
        context 'with an id' do
          let(:input) do
            <<~ASCIIDOC
              [[id]]
              [#{key}]
              --
              words
              --
            ASCIIDOC
          end
          it "renders the id in Elastic's custom template" do
            expect(converted).to include(<<~HTML)
              <div class="#{admon_class} admon">
              <div class="icon"></div>
              <div class="admon_content">
              <a id="id"></a>
              <p>words</p>
              </div>
              </div>
            HTML
          end
        end
      end
      let(:admon_class) { key.downcase }
      context 'note' do
        let(:key) { 'NOTE' }
        include_examples 'standard admonition'
      end
      context 'tip' do
        let(:key) { 'TIP' }
        include_examples 'standard admonition'
      end
      context 'important' do
        let(:key) { 'IMPORTANT' }
        include_examples 'standard admonition'
      end
      context 'caution' do
        let(:key) { 'CAUTION' }
        include_examples 'standard admonition'
      end
      context 'warning' do
        let(:key) { 'WARNING' }
        include_examples 'standard admonition'
      end
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
        ****
        Words
        ****
      ASCIIDOC
    end
    it 'renders like docbook' do
      expect(converted).to include(<<~HTML)
        <div class="sidebar">
        <div class="titlepage"></div>
        <p>Words</p>
        </div>
      HTML
    end
    context 'when there is a title' do
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
    context 'when there is a title' do
      let(:input) do
        <<~ASCIIDOC
          [[id]]
          ****
          Words
          ****
        ASCIIDOC
      end
      it 'renders like docbook' do
        expect(converted).to include(<<~HTML)
          <div class="sidebar">
          <a id="id"></a>
          <div class="titlepage"></div>
          <p>Words</p>
          </div>
        HTML
      end
    end
  end

  context 'an open block' do
    context 'that is empty' do
      let(:input) do
        <<~ASCIIDOC
          --
          Words.
          --
        ASCIIDOC
      end
      it 'just renders its contents' do
        expect(converted).to eq <<~HTML.strip
          <div id="preamble">
          <div class="sectionbody">
          <p>Words.</p>
          </div>
          </div>
        HTML
      end
    end
  end

  context 'tables' do
    context 'basic' do
      let(:input) do
        <<~ASCIIDOC
          |===
          |Col 1 | Col 2

          |Foo   | Bar
          |Baz   | Bort
          |===
        ASCIIDOC
      end
      it 'is wrapped in informaltable' do
        expect(converted).to include <<~HTML
          <div class="informaltable">
          <table border="1" cellpadding="4px">
        HTML
      end
      it 'contains the colgroups' do
        expect(converted).to include <<~HTML
          <colgroup>
          <col class="col_1"/>
          <col class="col_2"/>
          </colgroup>
        HTML
      end
      it 'contains the head' do
        expect(converted).to include <<~HTML
          <thead>
          <tr>
          <th align="left" valign="top">Col 1</th>
          <th align="left" valign="top">Col 2</th>
          </tr>
          </thead>
        HTML
      end
      it 'contains the body' do
        expect(converted).to include <<~HTML
          <tbody>
          <tr>
          <td align="left" valign="top"><p>Foo</p></td>
          <td align="left" valign="top"><p>Bar</p></td>
          </tr>
          <tr>
          <td align="left" valign="top"><p>Baz</p></td>
          <td align="left" valign="top"><p>Bort</p></td>
          </tr>
          </tbody>
        HTML
      end
    end
    context 'with asciidoc content' do
      let(:input) do
        <<~ASCIIDOC
          |===
          |Col 1

          a|
          . Foo
          |===
        ASCIIDOC
      end
      it 'contains the asciidoc content' do
        expect(converted).to include <<~HTML
          <td align="left" valign="top">
          <div class="olist orderedlist">
          <ol class="orderedlist">
          <li class="listitem">
          Foo
          </li>
          </ol>
          </div>
          </td>
        HTML
      end
    end
    context 'with a title' do
      let(:input) do
        <<~ASCIIDOC
          .Title
          |===
          |Col 1 | Col 2
          |===
        ASCIIDOC
      end
      it 'is wrapped in table' do
        expect(converted).to include <<~HTML
          <div class="table">
          <p class="title"><strong>Table 1. Title</strong></p>
          <div class="table-contents">
          <table border="1" cellpadding="4px" summary="Title">
        HTML
      end

      context 'and an id' do
        let(:input) do
          <<~ASCIIDOC
            [[id]]
            .Title
            |===
            |Col 1 | Col 2
            |===
          ASCIIDOC
        end
        it 'is wrapped in table' do
          expect(converted).to include <<~HTML
            <div class="table">
            <a id="id"></a>
            <p class="title"><strong>Table 1. Title</strong></p>
            <div class="table-contents">
            <table border="1" cellpadding="4px" summary="Title">
          HTML
        end
      end
    end
    context 'with an id' do
      let(:input) do
        <<~ASCIIDOC
          [[id]]
          |===
          |Col 1 | Col 2
          |===
        ASCIIDOC
      end
      it 'is wrapped in informaltable' do
        expect(converted).to include <<~HTML
          <div class="informaltable">
          <a id="id"></a>
          <table border="1" cellpadding="4px">
        HTML
      end
    end
    context 'with width' do
      let(:input) do
        <<~ASCIIDOC
          [width=50%]
          |===
          |Col 1 | Col 2
          |===
        ASCIIDOC
      end
      it 'has the width' do
        expect(converted).to include <<~HTML
          <table border="1" cellpadding="4px" width="50%">
        HTML
      end
    end
    context 'with role shorthand' do
      let(:input) do
        <<~ASCIIDOC
          [.role]
          |===
          |Col 1 | Col 2
          |===
        ASCIIDOC
      end
      it 'has the class' do
        expect(converted).to include <<~HTML
          <table border="1" cellpadding="4px" class="role">
        HTML
      end
    end
    context 'with roles shorthand' do
      let(:input) do
        <<~ASCIIDOC
          [.role1.role2]
          |===
          |Col 1 | Col 2
          |===
        ASCIIDOC
      end
      it 'has the classes' do
        expect(converted).to include <<~HTML
          <table border="1" cellpadding="4px" class="role1 role2">
        HTML
      end
    end
    context 'with role attribute' do
      let(:input) do
        <<~ASCIIDOC
          [role=role]
          |===
          |Col 1 | Col 2
          |===
        ASCIIDOC
      end
      it 'has the class' do
        expect(converted).to include <<~HTML
          <table border="1" cellpadding="4px" class="role">
        HTML
      end
    end
    context 'with colspan' do
      let(:input) do
        <<~ASCIIDOC
          |===
          2+|Col
          |===
        ASCIIDOC
      end
      it 'has the colspan' do
        expect(converted).to include <<~HTML.strip
          <td align="left" colspan="2" valign="top">
        HTML
      end
    end
    context 'with rowspan' do
      let(:input) do
        <<~ASCIIDOC
          |===
          .2+|Col
          |===
        ASCIIDOC
      end
      it 'has the rowspan' do
        expect(converted).to include <<~HTML.strip
          <td align="left" rowspan="2" valign="top">
        HTML
      end
    end
    context 'with horizontal alignment' do
      let(:input) do
        <<~ASCIIDOC
          [cols="<,^,>"]
          |===
          |1 |2 |3
          |===
        ASCIIDOC
      end
      it 'aligns the cells' do
        expect(converted).to include <<~HTML
          <td align="left" valign="top"><p>1</p></td>
          <td align="center" valign="top"><p>2</p></td>
          <td align="right" valign="top"><p>3</p></td>
        HTML
      end
    end
    context 'with vertical alignment' do
      let(:input) do
        <<~ASCIIDOC
          [cols=".<,.^,.>"]
          |===
          |1 |2 |3
          |===
        ASCIIDOC
      end
      it 'aligns the cells' do
        expect(converted).to include <<~HTML
          <td align="left" valign="top"><p>1</p></td>
          <td align="left" valign="middle"><p>2</p></td>
          <td align="left" valign="bottom"><p>3</p></td>
        HTML
      end
    end
    context 'with cell formatting' do
      shared_examples 'with formatting' do
        let(:input) do
          <<~ASCIIDOC
            [cols="#{code}"]
            |===
            |Cell
            |===
          ASCIIDOC
        end
        it 'includes the formatting' do
          expect(converted).to include <<~HTML.strip
            <td align="left" valign="top"><p>#{cell}</p></td>
          HTML
        end
      end
      context 'emphasis' do
        let(:code) { 'e' }
        let(:cell) { '<em>Cell</em>' }
        include_examples 'with formatting'
      end
      context 'header' do
        let(:code) { 'h' }
        let(:cell) do
          '<span class="strong strong"><strong>Cell</strong></span>'
        end
        include_examples 'with formatting'
      end
      context 'literal' do
        let(:code) { 'l' }
        let(:cell) { 'Cell' }
        include_examples 'with formatting'
      end
      context 'monospaced' do
        let(:code) { 'm' }
        let(:cell) { '<code class="literal">Cell</code>' }
        include_examples 'with formatting'
      end
      context 'explicit "none"' do
        let(:code) { 'd' } # "d" stands for default, apparently
        let(:cell) { 'Cell' }
        include_examples 'with formatting'
        context 'when the content is a couple of paragraphs' do
          let(:input) do
            <<~ASCIIDOC
              [cols="#{code}"]
              |===
              |Cell

              with

              paragraphs.
              |===
            ASCIIDOC
          end
          it 'includes the formatting' do
            expect(converted).to include <<~HTML.strip
              <td align="left" valign="top"><p>Cell</p>
              <p>with</p>
              <p>paragraphs.</p></td>
            HTML
          end
        end
      end
      context 'strong' do
        let(:code) { 's' }
        let(:cell) do
          '<span class="strong strong"><strong>Cell</strong></span>'
        end
        include_examples 'with formatting'
      end
      context 'verse' do
        let(:code) { 'v' }
        let(:cell) { 'Cell' }
        include_examples 'with formatting'
      end
    end
  end

  context 'a quote' do
    let(:input) do
      <<~ASCIIDOC
        [quote]
        __________________________
        Baz
        __________________________
      ASCIIDOC
    end
    it 'is wrapped in a blockquote' do
      expect(converted).to include <<~HTML
        <blockquote>
        <p>Baz</p>
        </blockquote>
      HTML
    end

    context 'with an attribution' do
      let(:input) do
        <<~ASCIIDOC
          [quote, Brendan Francis Behan]
          __________________________
          Once we accept our limits, we go beyond them.
          __________________________
        ASCIIDOC
      end
      it 'looks like docbook' do
        expect(converted).to include <<~HTML
          <div class="blockquote">
          <table border="0" class="blockquote" summary="Block quote">
          <tr>
          <td valign="top" width="10%"></td>
          <td valign="top" width="80%">
          <p>Once we accept our limits, we go beyond them.</p>
          </td>
          <td valign="top" width="10%"></td>
          </tr>
          <tr>
          <td valign="top" width="10%"></td>
          <td align="right" colspan="2" valign="top">
          -- <span class="attribution">Brendan Francis Behan</span>
          </td>
          </tr>
          </table>
          </div>
        HTML
      end
    end
  end

  context 'example' do
    let(:input) do
      <<~ASCIIDOC
        ====
        Words
        ====
      ASCIIDOC
    end
    it 'is wrapped in an exampleblock' do
      expect(converted).to include <<~HTML
        <div class="exampleblock">
        <div class="content">
        <p>Words</p>
        </div>
        </div>
      HTML
    end

    context 'with a title' do
      let(:input) do
        <<~ASCIIDOC
          .Title
          ====
          Words
          ====
        ASCIIDOC
      end
      it 'is wrapped in an example' do
        expect(converted).to include <<~HTML
          <div class="example">
          <p class="title"><strong>Example 1. Title</strong></p>
          <div class="example-contents">
          <p>Words</p>
          </div>
          </div>
        HTML
      end
    end
    context 'collapsible' do
      let(:input) do
        <<~ASCIIDOC
          [%collapsible]
          .Title
          ====
          Words
          ====
        ASCIIDOC
      end
      it "uses asciidoctor's default" do
        expect(converted).to include <<~HTML
          <details>
          <summary class="title">Title</summary>
          <div class="content">
          <p>Words</p>
          </div>
        HTML
      end
    end
  end
end
