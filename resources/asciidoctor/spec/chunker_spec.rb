# frozen_string_literal: true

require 'chunker/extension'
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
  let(:backend) { :html5 }
  let(:standalone) { true }

  shared_examples 'standard page' \
    do |prev_page, prev_title, next_page, next_title|
    context 'the <head>' do
      it 'contains the charset' do
        expect(contents).to include(<<~HTML)
          <meta charset="UTF-8">
        HTML
      end
      it 'contains the home link' do
        expect(contents).to include(<<~HTML)
          <link rel="home" href="index.html" title="Title"/>
        HTML
      end
      if prev_page
        it 'contains the prev link' do
          expect(contents).to include(<<~HTML)
            <link rel="prev" href="#{prev_page}.html" title="#{prev_title}"/>
          HTML
        end
      else
        it "doesn't contain the prev link" do
          expect(contents).not_to include('rel="prev"')
        end
      end
      if next_page
        it 'contains the next link' do
          expect(contents).to include(<<~HTML)
            <link rel="next" href="#{next_page}.html" title="#{next_title}"/>
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
      if prev_page
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
      if next_page
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
      context 'there is are two level 1 sections' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[s1]]
            == Section 1

            [[linkme]]
            Words words.

            <<s2>>

            [[s2]]
            == Section 2

            Words again.

            <<linkme>>
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'standard page', nil, nil, 's1', 'Section 1'
          it 'contains a link to the first section' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s1.html">Section 1</a></li>
            HTML
          end
          it 'contains a link to the second section' do
            expect(converted).to include(<<~HTML.strip)
              <li><a href="s2.html">Section 2</a></li>
            HTML
          end
          it "doesn't contain breadcrumbs" do
            expect(converted).not_to include('<div class="breadcrumbs">')
          end
        end
        file_context 'the first section', 's1.html' do
          include_examples 'standard page', 'index', 'Title', 's2', 'Section 2'
          include_examples 'subpage'
          it 'contains the correct title' do
            expect(contents).to include('<title>Section 1 | Title</title>')
          end
          it 'contains the heading' do
            expect(contents).to include('<h2 id="s1">Section 1</h2>')
          end
          it 'contains the contents' do
            expect(contents).to include '<p>Words words.</p>'
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-node">Section 1</span>
              </div>
            HTML
          end
          it 'contains a link to the second section' do
            expect(contents).to include('<a href="s2.html">Section 2</a>')
          end
        end
        file_context 'the second section', 's2.html' do
          include_examples 'standard page', 's1', 'Section 1', nil, nil
          include_examples 'subpage'
          it 'contains the correct title' do
            expect(contents).to include('<title>Section 2 | Title</title>')
          end
          it 'contains the heading' do
            expect(contents).to include('<h2 id="s2">Section 2</h2>')
          end
          it 'contains the contents' do
            expect(contents).to include '<p>Words again.</p>'
          end
          it 'contains the breadcrumbs' do
            expect(contents).to include <<~HTML
              <div class="breadcrumbs">
              <span class="breadcrumb-link"><a href="index.html">Title</a></span>
              »
              <span class="breadcrumb-node">Section 2</span>
              </div>
            HTML
          end
          it 'contains a link to an element in the first section' do
            expect(contents).to include('<a href="s1.html#linkme">[linkme]</a>')
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
          include_examples 'standard page', nil, nil, 'l1', 'Level 1'
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
          include_examples 'standard page', 'index', 'Title', nil, nil
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
          include_examples 'standard page', nil, nil, 'l0', 'L0'
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
          include_examples 'standard page', 'index', 'Title', 'l1', 'L1'
          include_examples 'subpage'
          it 'contains the header of the level 0 section' do
            expect(contents).to include('<h1 id="l0" class="sect0">L0</h1>')
          end
          it 'contains the contents' do
            expect(contents).to include('Words words.')
          end
        end
        file_context 'the level 1 section', 'l1.html' do
          include_examples 'standard page', 'l0', 'L0', nil, nil
          include_examples 'subpage'
          it 'contains the header of the level 1 section' do
            expect(contents).to include('<h2 id="l1">L1</h2>')
          end
          it 'contains contents' do
            expect(contents).to include('<p>Words again.</p>')
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
      context 'there is are a few sections' do
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
          include_examples 'standard page', nil, nil, 's1', 'S1'
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
          include_examples 'standard page', 'index', 'Title', 's1_1', 'S1_1'
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
          include_examples 'standard page', 's1', 'S1', 's2', 'S2'
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
          include_examples 'standard page', 's1_1', 'S1_1', 's2_1', 'S2_1'
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
          include_examples 'standard page', 's2', 'S2', 's2_2', 'S2_2'
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
          include_examples 'standard page', 's2_1', 'S2_1', nil, nil
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
