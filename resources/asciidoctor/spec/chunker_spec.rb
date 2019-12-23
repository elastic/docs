# frozen_string_literal: true

require_relative '../../test/dsl/file_context'
require_relative '../../test/matcher/file_exist'
require 'chunker/extension'
require 'docbook_compat/extension'
require 'fileutils'
require 'tmpdir'

RSpec.describe Chunker do
  before(:each) do
    Asciidoctor::Extensions.register Chunker
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_context 'convert without logs'
  let(:standalone) { true }
  let(:home_title) { 'Title' }
  let(:prev_title) { prev_page == 'index' ? 'Title' : prev_page.upcase }
  let(:next_title) { next_page.upcase }
  let(:prev_link_title) { prev_title }
  let(:next_link_title) { next_title }

  shared_examples 'standard page' do |prev_arg, next_arg|
    let(:prev_page) { prev_arg }
    let(:next_page) { next_arg }
    context 'the <head>' do
      it 'contains the charset' do
        expect(contents).to include(<<~HTML)
          <meta charset="UTF-8">
        HTML
      end
      it 'contains the home link' do
        expect(contents).to include(<<~HTML)
          <link rel="home" href="index.html" title="#{home_title}"/>
        HTML
      end
      if prev_arg
        it 'contains the prev link' do
          expect(contents).to include(<<~HTML)
            <link rel="prev" href="#{prev_page}.html" title="#{prev_link_title}"/>
          HTML
        end
      else
        it "doesn't contain the prev link" do
          expect(contents).not_to include('rel="prev"')
        end
      end
      if next_arg
        it 'contains the next link' do
          expect(contents).to include(<<~HTML)
            <link rel="next" href="#{next_page}.html" title="#{next_link_title}"/>
          HTML
        end
      else
        it "doesn't contain the next link" do
          expect(contents).not_to include('rel="next"')
        end
      end
      it "doesn't contain the builtin asciidoctor stylesheet" do
        # We turned the stylesheet off
        expect(contents).not_to include('<style')
      end
    end
    context 'the <body>' do
      it 'contains the navheader' do
        expect(contents).to include('<div class="navheader">')
      end
      it 'contains the navfooter' do
        expect(contents).to include('<div class="navfooter">')
      end
      if prev_arg && prev_arg != 'index'
        it 'contains the prev nav' do
          expect(contents).to include(<<~HTML)
            <span class="prev">
            <a href="#{prev_page}.html">« #{prev_title}</a>
            </span>
          HTML
        end
      else
        it 'contains an empty prev nav' do
          expect(contents).to include(<<~HTML)
            <span class="prev">
            </span>
          HTML
        end
      end
      if next_arg
        it 'contains the next nav' do
          expect(contents).to include(<<~HTML)
            <span class="next">
            <a href="#{next_page}.html">#{next_title} »</a>
            </span>
          HTML
        end
      else
        it 'contains an empty next nav' do
          expect(contents).to include(<<~HTML)
            <span class="next">
            </span>
          HTML
        end
      end
    end
  end

  shared_examples 'subpage' do
    it "doesn't contain the main title" do
      expect(contents).not_to include('<h1>Title</h1>')
    end
  end

  context 'when outdir is configured' do
    let(:outdir) { Dir.mktmpdir }
    after(:example) { FileUtils.remove_entry outdir }
    ##
    # Build a path to a file in the destination directory.
    # Needed by file_context.
    def dest_file(file)
      converted
      File.join outdir, file
    end
    context 'when chunk level is 1' do
      let(:convert_attributes) do
        {
          'outdir' => outdir,
          'chunk_level' => 1,
          # Shrink the output slightly so it is easier to read
          'stylesheet!' => false,
          # We always enable the toc for multi-page books
          'toc' => '',
        }
      end
      context 'there are two level 1 sections' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[s1]]
            == Section "1"

            [[linkme]]
            Words words.footnote:[foo]

            <<s2>>

            [[s2]]
            == Section `2`

            Words again.

            <<linkme,override text>>

            <<s1,override text>>

            footnote:[bar]
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 's1'
          let(:next_title) { 'Section "1"' }
          let(:next_link_title) { 'Section &quot;1&quot;' }
          it 'contains a link to the first section' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s1.html">Section "1"</a></li>
            HTML
          end
          it 'contains a link to the second section' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s2.html">Section <code>2</code></a></li>
            HTML
          end
          it "doesn't contain breadcrumbs" do
            expect(converted).not_to include('<div class="breadcrumbs">')
          end
          it "doesn't contain any footnotes" do
            expect(converted).not_to include('<div id="footnotes">')
          end
        end
        file_context 'the first section', 's1.html' do
          include_examples 'standard page', 'index', 's2'
          let(:next_title) { 'Section <code>2</code>' }
          let(:next_link_title) { 'Section 2' }
          include_examples 'subpage'
          it 'contains the correct title' do
            expect(contents).to include('<title>Section "1" | Title</title>')
          end
          it 'contains the heading' do
            expect(contents).to include('<h2 id="s1">Section "1"</h2>')
          end
          it 'contains the contents' do
            expect(contents).to include <<~HTML
              <p>Words words.<sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup></p>
            HTML
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-node">Section "1"</span>
              </div>
            HTML
          end
          it 'contains a link to the second section' do
            expect(contents).to include(
              '<a href="s2.html">Section <code>2</code></a>'
            )
          end
          it 'contains the footnote' do
            expect(contents).to include <<~HTML
              <div id="footnotes">
              <div class="footnote" id="_footnotedef_1">
              <sup>[<a href="#_footnoteref_1">1</a>]</sup> foo
              </div>
              </div>
            HTML
          end
        end
        file_context 'the second section', 's2.html' do
          include_examples 'standard page', 's1', nil
          let(:prev_title) { 'Section "1"' }
          let(:prev_link_title) { 'Section &quot;1&quot;' }
          include_examples 'subpage'
          it 'contains the correct title' do
            expect(contents).to include('<title>Section 2 | Title</title>')
          end
          it 'contains the heading' do
            expect(contents).to include(
              '<h2 id="s2">Section <code>2</code></h2>'
            )
          end
          it 'contains the contents' do
            expect(contents).to include '<p>Words again.</p>'
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-node">Section <code>2</code></span>
              </div>
            HTML
          end
          it 'contains a link to an element in the first section' do
            expect(contents).to include(
              '<a href="s1.html#linkme">override text</a>'
            )
          end
          it 'contains a link to the first section with override text' do
            expect(contents).to include('<a href="s1.html">override text</a>')
          end
          it 'contains the footnote' do
            expect(contents).to include <<~HTML
              <div id="footnotes">
              <div class="footnote" id="_footnotedef_2">
              <sup>[<a href="#_footnoteref_2">2</a>]</sup> bar
              </div>
              </div>
            HTML
          end
        end
      end
      context 'there is a level 2 section' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[l1]]
            == Level 1

            Words words.

            [[l2]]
            === Level 2

            Words again.
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 'l1'
          let(:next_title) { 'Level 1' }
          it 'contains a link to the level 1 section' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="l1.html">Level 1</a></li>
            HTML
          end
          it "doesn't contain a link to the level 2 section" do
            expect(converted).not_to include(<<~HTML.strip)
              <a href="l2.html">
            HTML
          end
        end
        file_context 'the level one section', 'l1.html' do
          include_examples 'standard page', 'index', nil
          include_examples 'subpage'
          it 'contains the header of the level 1 section' do
            expect(contents).to include('<h2 id="l1">Level 1</h2>')
          end
          it 'contains first paragraph' do
            expect(contents).to include('<p>Words words.</p>')
          end
          it 'contains the header of the level 2 section' do
            expect(contents).to include('<h3 id="l2">Level 2</h3>')
          end
          it 'contains the contents of the level 2 section' do
            expect(contents).to include('<p>Words again.</p>')
          end
          it "doesn't contain a link to the level 2 section" do
            expect(converted).not_to include(<<~HTML.strip)
              <a href="l2.html">
            HTML
          end
        end
        it 'there is no file named for the level 2 section' do
          expect(File.join(outdir, 'l2.html')).not_to file_exist
        end
      end
      context 'there is a level 0 section' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[l0]]
            = L0

            Words words.

            [[l1]]
            == L1

            Words again.
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 'l0'
          it 'contains a link to the level 0 section' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="l0.html">L0</a>
            HTML
          end
          it 'contains a link to the level 1 section' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="l1.html">L1</a></li>
            HTML
          end
        end
        file_context 'the level 0 section', 'l0.html' do
          include_examples 'standard page', 'index', 'l1'
          include_examples 'subpage'
          it 'contains the header of the level 0 section' do
            expect(contents).to include('<h1 id="l0" class="sect0">L0</h1>')
          end
          it 'contains the contents' do
            expect(contents).to include('Words words.')
          end
        end
        file_context 'the level 1 section', 'l1.html' do
          include_examples 'standard page', 'l0', nil
          include_examples 'subpage'
          it 'contains the header of the level 1 section' do
            expect(contents).to include('<h2 id="l1">L1</h2>')
          end
          it 'contains contents' do
            expect(contents).to include('<p>Words again.</p>')
          end
        end
      end
      context 'when there is title-extra' do
        let(:convert_attributes) do
          {
            'outdir' => outdir,
            'chunk_level' => 1,
            # Shrink the output slightly so it is easier to read
            'stylesheet!' => false,
            # We always enable the toc for multi-page books
            'toc' => '',
            'title-extra' => ' [fooo]',
          }
        end
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[s1]]
            == S1
          ASCIIDOC
        end
        let(:home_title) { 'Title [fooo]' }
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 's1'
          it 'contains the correct title' do
            expect(contents).to include('<title>Title</title>')
          end
        end
        file_context 'the section', 's1.html' do
          include_examples 'standard page', 'index', nil
          let(:prev_title) { 'Title [fooo]' }
          include_examples 'subpage'
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title [fooo]</a></span>
              »
              <span class="breadcrumb-node">S1</span>
              </div>
            HTML
          end
        end
      end
      context 'there are many spaces in the title' do
        let(:input) do
          <<~ASCIIDOC
            = Title    With   Spaces

            [[s]]
            == S

            Words.
          ASCIIDOC
        end
        let(:home_title) { 'Title With Spaces' }
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 's'
        end
        file_context 'the section', 's.html' do
          include_examples 'standard page', 'index', nil
          let(:prev_title) { 'Title With Spaces' }
          include_examples 'subpage'
        end
      end
      context 'there is html in a section title' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[s]]
            == Section `foo`

            Words.
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 's'
          let(:next_title) { 'Section <code>foo</code>' }
          let(:next_link_title) { 'Section foo' }
          it 'contains a link to the section' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s.html">Section <code>foo</code></a></li>
            HTML
          end
        end
        file_context 'the section', 's.html' do
          include_examples 'standard page', 'index', nil
          include_examples 'subpage'
          it 'contains the heading' do
            expect(contents).to include(
              '<h2 id="s">Section <code>foo</code></h2>'
            )
          end
        end
      end
      context 'there is a subtitle on a section' do
        before(:each) do
          # We need docbook compat to verify that we disabled the
          # title separator. We unregister_all first because the order that we
          # register the plugins matters.
          Asciidoctor::Extensions.unregister_all
          Asciidoctor::Extensions.register DocbookCompat
          Asciidoctor::Extensions.register Chunker
        end

        let(:input) do
          <<~ASCIIDOC
            = Title

            [[s]]
            == Section: With subtitle

            Words.
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 's'
          let(:next_title) { 'Section: With subtitle' }
          it 'contains a link to the section' do
            expect(converted).to include(<<~HTML.strip)
              <li><span class="chapter"><a href="s.html">Section: With subtitle</a></span>
              </li>
            HTML
          end
        end
        file_context 'the section', 's.html' do
          include_examples 'standard page', 'index', nil
          include_examples 'subpage'
          it 'contains the correct title' do
            expect(contents).to include(
              '<title>Section: With subtitle | Title | Elastic</title>'
            )
          end
          it 'contains the heading' do
            expect(contents).to include(
              '<h1 class="title"><a id="s"></a>Section: With subtitle</h1>'
            )
          end
          it 'contains the contents' do
            expect(contents).to include <<~HTML
              <p>Words.</p>
            HTML
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-node">Section: With subtitle</span>
              </div>
            HTML
          end
        end
      end
    end
    context 'when chunk level is 2' do
      let(:convert_attributes) do
        {
          'outdir' => outdir,
          'chunk_level' => 2,
          # Shrink the output slightly so it is easier to read
          'stylesheet!' => false,
          # We always enable the toc for multi-page books
          'toc' => '',
        }
      end
      context 'there are a few sections' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[s1]]
            == S1

            <<S2_1_1>>

            [[s1_1]]
            === S1_1

            [[s2]]
            == S2

            [[s2_1]]
            === S2_1

            [[s2_1_1]]
            ==== S2_1_1

            [[s2_2]]
            === S2_2
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 's1'
          it 'contains a link to the level 1 sections' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s1.html">S1</a>
            HTML
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s2.html">S2</a>
            HTML
          end
          it 'contains a link to the level 2 sections' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s1_1.html">S1_1</a></li>
            HTML
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s2_1.html">S2_1</a></li>
            HTML
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s2_2.html">S2_2</a></li>
            HTML
          end
          it "doesn't contain a link to the level 3 section" do
            expect(converted).not_to include('S2_1_1')
          end
        end
        file_context 'the first level 1 section', 's1.html' do
          include_examples 'standard page', 'index', 's1_1'
          include_examples 'subpage'
          it 'contains the heading' do
            expect(contents).to include('<h2 id="s1">S1</h2>')
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-node">S1</span>
              </div>
            HTML
          end
          it 'contains a link to the level 3 section' do
            expect(contents).to include('<a href="s2_1.html#s2_1_1">S2_1_1</a>')
          end
        end
        file_context 'the first level 2 section', 's1_1.html' do
          include_examples 'standard page', 's1', 's2'
          include_examples 'subpage'
          it 'contains the heading' do
            expect(contents).to include('<h3 id="s1_1">S1_1</h3>')
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-link"><a href="s1.html">S1</a></span>
              »
              <span class="breadcrumb-node">S1_1</span>
              </div>
            HTML
          end
        end
        file_context 'the second level 1 section', 's2.html' do
          include_examples 'standard page', 's1_1', 's2_1'
          include_examples 'subpage'
          it 'contains the heading' do
            expect(contents).to include('<h2 id="s2">S2</h2>')
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-node">S2</span>
              </div>
            HTML
          end
        end
        file_context 'the second level 2 section', 's2_1.html' do
          include_examples 'standard page', 's2', 's2_2'
          include_examples 'subpage'
          it 'contains the heading' do
            expect(contents).to include('<h3 id="s2_1">S2_1</h3>')
          end
          it 'contains the level 3 section' do
            expect(contents).to include('<h4 id="s2_1_1">S2_1_1</h4>')
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-link"><a href="s2.html">S2</a></span>
              »
              <span class="breadcrumb-node">S2_1</span>
              </div>
            HTML
          end
        end
        file_context 'the last level 2 section', 's2_2.html' do
          include_examples 'standard page', 's2_1', nil
          include_examples 'subpage'
          it 'contains the heading' do
            expect(contents).to include('<h3 id="s2_2">S2_2</h3>')
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-link"><a href="s2.html">S2</a></span>
              »
              <span class="breadcrumb-node">S2_2</span>
              </div>
            HTML
          end
        end
      end
      context 'there is an appendix' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[s1]]
            == S1

            [appendix,id=app]
            == Foo

            [[app_1]]
            === Foo 1

            [[app_2]]
            === Foo 2
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, 's1'
          it 'contains a link to the level 1 sections' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s1.html">S1</a>
            HTML
            expect(converted).to include(<<~HTML.strip)
              <li><a href="app.html">Appendix A: Foo</a>
            HTML
          end
          it 'contains a link to the level 2 sections' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="app_1.html">Foo 1</a></li>
            HTML
            expect(converted).to include(<<~HTML.strip)
              <li><a href="app_2.html">Foo 2</a></li>
            HTML
          end
        end
        file_context 'the section', 's1.html' do
          include_examples 'standard page', 'index', 'app'
          let(:next_title) { 'Appendix A: Foo' }
          include_examples 'subpage'
        end
        file_context 'the appendix', 'app.html' do
          include_examples 'standard page', 's1', 'app_1'
          let(:next_title) { 'Foo 1' }
          include_examples 'subpage'
          it 'contains the correct title' do
            expect(contents).to include(
              '<title>Appendix A: Foo | Title</title>'
            )
          end
          it 'contains the heading' do
            expect(contents).to include('<h2 id="app">Appendix A: Foo</h2>')
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-node">Foo</span>
              </div>
            HTML
          end
        end
        file_context 'the first page in the appendix', 'app_1.html' do
          include_examples 'standard page', 'app', 'app_2'
          let(:prev_title) { 'Appendix A: Foo' }
          let(:next_title) { 'Foo 2' }
          include_examples 'subpage'
          it 'contains the heading' do
            expect(contents).to include('<h3 id="app_1">Foo 1</h3>')
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-link"><a href="app.html">Foo</a></span>
              »
              <span class="breadcrumb-node">Foo 1</span>
              </div>
            HTML
          end
        end
        file_context 'the first page in the appendix', 'app_2.html' do
          include_examples 'standard page', 'app_1', nil
          let(:prev_title) { 'Foo 1' }
          include_examples 'subpage'
          it 'contains the heading' do
            expect(contents).to include('<h3 id="app_2">Foo 2</h3>')
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-link"><a href="app.html">Foo</a></span>
              »
              <span class="breadcrumb-node">Foo 2</span>
              </div>
            HTML
          end
        end
      end
    end
  end
  context "when outdir isn't configured" do
    context 'the plugin does nothing' do
      let(:input) do
        <<~ASCIIDOC
          = Title

          [[s1]]
          == Section 1

          Words words.

          [[s2]]
          == Section 2

          Words again.
        ASCIIDOC
      end
      context 'the main output' do
        it 'contains all the headings' do
          expect(converted).to include('<h2 id="s1">Section 1</h2>')
          expect(converted).to include('<h2 id="s2">Section 2</h2>')
        end
      end
    end
  end
end
