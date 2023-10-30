# frozen_string_literal: true

require 'fileutils'
require 'net/http'

require_relative 'spec_helper'

RSpec.describe 'building a single book' do
  HEADER = <<~ASCIIDOC
    = Title

    [[chapter]]
    == Chapter
  ASCIIDOC

  let(:emdash)           { '&#8212;' }
  let(:ellipsis)         { '&#8230;' }
  let(:zero_width_space) { '&#8203;' }

  context 'for a minimal book' do
    shared_context 'expected' do |file_name|
      convert_single_before_context do |src|
        src.write file_name, <<~ASCIIDOC
          #{HEADER}
          This is a minimal viable asciidoc file for use with build_docs. The
          actual contents of this paragraph aren't important but having a
          paragraph here is required.
        ASCIIDOC
      end

      page_context 'index.html' do
        it 'has the right title' do
          expect(title).to eq('Title')
        end
        it 'has a link to the css' do
          expect(head).to include(<<~HTML)
            <link rel="stylesheet" type="text/css" href="/guide/static/styles.css" />
          HTML
        end
        it 'has a link to the js' do
          expect(contents).to include(<<~HTML)
            <script type="text/javascript" src="/guide/static/docs.js"></script>
          HTML
        end
        it 'has the right language' do
          expect(language).to eq('en')
        end
        it 'has an empty initial js state' do
          expect(contents).to initial_js_state(be_empty)
        end
      end
      page_context 'toc.html' do
        it "doesn't have the initial js state" do
          # because we didn't apply the template
          expect(contents).to initial_js_state(be_nil)
        end
      end
      page_context 'raw/toc.html'
      page_context 'raw/index.html' do
        it "doesn't have the xml prolog" do
          expect(contents).not_to include('?xml')
        end
        it 'has the html5 doctype' do
          expect(contents).to include("<!DOCTYPE html>\n")
        end
        it "doesn't have any xmlns declarations" do
          expect(contents).not_to include('xmlns=')
        end
        it "doesn't have a meta generator" do
          expect(contents).not_to include('<meta name="generator"')
        end
        it "doesn't have a meta description" do
          expect(contents).not_to include('<meta name="description"')
        end
        it "doesn't have any xml:lang tags" do
          expect(contents).not_to include('xml:lang=')
        end
        it 'has a trailing newline' do
          expect(contents).to end_with("\n")
        end
        it 'has the right title in head' do
          expect(head_title).to match(/Title\s+\|\s+Elastic/m)
        end
        it 'has the right title' do
          expect(title).to eq('Title')
        end
        it "doesn't have the initial js state" do
          # because we don't apply the template which is how that gets in there
          expect(contents).to initial_js_state(be_nil)
        end
      end
      page_context 'chapter.html' do
        it 'has the right title in head' do
          expect(head_title).to match(/Chapter\s+\|\s+Title\s+\|\s+Elastic/m)
        end
        it 'has the right title' do
          expect(title).to eq('Chapter')
        end
      end
      page_context 'raw/chapter.html' do
        it 'has the right title in head' do
          expect(head_title).to match(/Chapter\s+\|\s+Title\s+\|\s+Elastic/m)
        end
        it 'has the right title' do
          expect(title).to eq('Chapter')
        end
      end
    end

    context 'when the file ends in .asciidoc' do
      include_context 'expected', 'minimal.asciidoc'
    end

    context 'when the file ends in .adoc' do
      include_context 'expected', 'minimal.adoc'
    end
  end

  context "when there isn't an elastic remote" do
    convert_single_before_context do |src|
      src.add_elastic_remote = false
      src.write 'index.asciidoc', <<~ASCIIDOC
        #{HEADER}
        This is a minimal viable asciidoc file for use with build_docs. The
        actual contents of this paragraph aren't important but having a
        paragraph here is required.
      ASCIIDOC
    end
    let(:repo) { src.repo 'src' }
    context 'the logs' do
      it 'say they are using the first remote intead' do
        expect(outputs[0]).to include(<<~LOG)
          Couldn't find an Elastic remote for #{repo.root}. Generating edit links targeting the first remote instead.
        LOG
      end
    end
    page_context 'chapter.html' do
      it 'has an "unknown" edit url' do
        expect(body).to include(<<~HTML.strip)
          <a class="edit_me" rel="nofollow" title="Edit this page on GitHub" href="unknown/edit/master/index.asciidoc">edit</a>
        HTML
      end
    end
  end

  context 'when one file includes another' do
    convert_single_before_context do |src|
      src.write 'included.asciidoc', 'I am tiny.'
      src.write 'index.asciidoc', <<~ASCIIDOC
        #{HEADER}
        I include "included" between here

        include::included.asciidoc[]

        and here.
      ASCIIDOC
    end

    page_context 'chapter.html' do
      it 'contains the index text' do
        expect(body).to include('I include "included"')
      end
      it 'contains the included text' do
        expect(body).to include('I am tiny.')
      end
    end
  end

  context 'for "interesting" inputs' do
    context 'for a book that contains an em dash' do
      convert_single_before_context do |src|
        src.write 'index.asciidoc', <<~ASCIIDOC
          #{HEADER}
          I have an em dash between some--words.
        ASCIIDOC
      end
      page_context 'chapter.html' do
        it 'the emdash is followed by a zero width space' do
          expect(body).to include("some#{emdash}#{zero_width_space}words")
        end
      end
    end
    context 'for a book that contains an ellipsis' do
      convert_single_before_context do |src|
        src.write 'index.asciidoc', <<~ASCIIDOC
          #{HEADER}
          I have an ellipsis between some...words.
        ASCIIDOC
      end
      page_context 'chapter.html' do
        it 'the ellipsis is followed by a zero width space' do
          expect(body).to include("some#{ellipsis}#{zero_width_space}words")
        end
      end
    end
    context 'for a book that contains an empty table cell' do
      convert_single_before_context do |src|
        src.write 'index.asciidoc', <<~ASCIIDOC
          #{HEADER}
          |===
          | Title | Other Title
          |       | Empty cell before this one
          |===
        ASCIIDOC
      end
      let(:empty_cell) do
        <<~HTML.strip
          <td align="left" valign="top"><p></p></td>
        HTML
      end
      let(:non_empty_cell) do
        <<~HTML.strip
          <td align="left" valign="top"><p>Empty cell before this one</p></td>
        HTML
      end
      page_context 'chapter.html' do
        it "the empty cell doesn't contain any other tags" do
          # We match on the empty cell followed by the non-empty cell so we
          # can be sure we're matching the right part of the table.
          expect(body).to include <<~HTML
            <tr>
            #{empty_cell}
            #{non_empty_cell}
            </tr>
          HTML
        end
      end
    end
    context 'for a book that has a reference to a floating title' do
      convert_single_before_context do |src|
        src.write 'index.asciidoc', <<~ASCIIDOC
          #{HEADER}
          <<floater>>

          [float]
          [[floater]]
          == Floater
        ASCIIDOC
      end
      page_context 'chapter.html' do
        it "there isn't an edit me link in the link to the section" do
          expect(body).to include(<<~HTML.strip)
            <a class="xref" href="chapter.html#floater" title="Floater">Floater</a>
          HTML
        end
      end
    end
  end

  shared_context 'care admonition' do
    page_context 'chapter.html' do
      it 'includes the warning admonition' do
        expect(body).to include(
          '<div class="warning admon">'
        )
      end
    end
  end
  context 'when the book contains beta[]' do
    include_context 'care admonition'
    convert_single_before_context do |src|
      src.write 'index.asciidoc', <<~ASCIIDOC
        #{HEADER}
        beta[]

        Words
      ASCIIDOC
    end
    page_context 'chapter.html' do
      it 'includes the beta text' do
        expect(body).to include(
          'The design and code is less mature than official GA features'
        )
      end
    end
  end
  context 'when the book contains experimental[]' do
    include_context 'care admonition'
    convert_single_before_context do |src|
      src.write 'index.asciidoc', <<~ASCIIDOC
        #{HEADER}
        experimental[]

        Words
      ASCIIDOC
    end
    page_context 'chapter.html' do
      it 'includes the experimental text' do
        expect(body).to include(
          'This functionality is in technical preview and may be changed or '\
          'removed in a future release. Elastic will work to fix '\
          'any issues, but features in technical preview are not subject to '\
          'the support SLA of official GA features.'
        )
      end
    end
  end
  context 'when there is a link to elastic.co' do
    convert_single_before_context do |src|
      src.write 'index.asciidoc', <<~ASCIIDOC
        = Title

        [[chapter]]
        == Chapter
        https://www.elastic.co/cloud/[link]
      ASCIIDOC
    end
    page_context 'chapter.html' do
      it 'contains an absolute link to www.elatic.co' do
        expect(body).to include(<<~HTML.strip)
          <a href="https://www.elastic.co/cloud/" class="ulink" target="_top">link</a>
        HTML
      end
    end
  end

  context 'regarding the xpack tag' do
    let(:edit_me) do
      <<~HTML.strip
        <a class="edit_me" rel="nofollow" title="Edit this page on GitHub" href="https://github.com/elastic/docs/edit/master/index.asciidoc">edit</a>
      HTML
    end
    let(:xpack_tag) do
      <<~HTML.strip
        <a class="xpack_tag" href="/subscriptions"></a>
      HTML
    end
    let(:rx) { %r{<#{h} class="title"><a id="#{id}"></a>(.+?)</#{h}>} }
    let(:title_tag) do
      return unless body

      m = rx.match(body)
      raise "Can't find title_tag with #{rx} in #{body}" unless m

      m[1]
    end
    shared_examples 'xpack tag title' do |has_tag|
      it 'contains the edit_me link' do
        expect(title_tag).to include(edit_me)
      end
      if has_tag
        it 'contains the xpack tag' do
          expect(title_tag).to include(xpack_tag)
        end
      else
        it "doesn't contain the xpack tag" do
          expect(title_tag).not_to include(xpack_tag)
        end
      end
    end
    shared_examples 'part page titles' do |onpart|
      page_context 'part.html' do
        let(:h) { 'h1' }
        let(:id) { 'part' }
        include_examples 'xpack tag title', onpart
      end
    end
    shared_examples 'chapter page titles' do |onchapter, onfloater, onsection|
      page_context 'chapter.html' do
        let(:h) { 'h2' }
        context 'the chapter title' do
          let(:id) { 'chapter' }
          include_examples 'xpack tag title', onchapter
        end
        context 'the section title' do
          let(:id) { 'section' }
          include_examples 'xpack tag title', onsection
        end
        context 'the float title' do
          let(:rx) { %r{<h2><a id="floater"></a>(.+?)</h2>} }
          include_examples 'xpack tag title', onfloater
        end
      end
    end

    def self.xpack_tag_context(onpart, onchapter, onfloater, onsection,
                               hide_xpack)
      convert_single_before_context do |src|
        index = xpack_tag_test_asciidoc onpart, onchapter, onfloater, onsection,
                                        hide_xpack
        src.write 'index.asciidoc', index
      end

      include_examples 'part page titles',
                       onpart && !hide_xpack
      include_examples 'chapter page titles', onchapter && !hide_xpack,
                       onfloater && !hide_xpack, onsection && !hide_xpack
    end

    def self.xpack_tag_test_asciidoc(onpart, onchapter, onfloater, onsection,
                                     hide_xpack)
      <<~ASCIIDOC
        = Title

        #{hide_xpack ? ':hide-xpack-tags: true' : ''}

        #{onpart ? '[role="xpack"]' : ''}
        [[part]]
        = Part

        #{onchapter ? '[role="xpack"]' : ''}
        [[chapter]]
        == Chapter

        Chapter words.

        [[floater]]
        [float]
        == #{onfloater ? '[xpack]#Floater#' : 'Floater'}

        Floater words.

        #{onsection ? '[role="xpack"]' : ''}
        [[section]]
        === Section

        Section words.
      ASCIIDOC
    end

    context 'when not hiding xpack tags' do
      context 'when the xpack role is on a part' do
        xpack_tag_context true, false, false, false, false
      end
      context 'when the xpack role is on a chapter' do
        xpack_tag_context false, true, false, false, false
      end
      context 'when the xpack role is on a floating title' do
        xpack_tag_context false, false, true, false, false
      end
      context 'when the xpack role is on a section' do
        xpack_tag_context false, false, false, true, false
      end
      context 'when the xpack role is on everything' do
        xpack_tag_context true, true, true, true, false
      end
    end
    context 'when hiding xpack tags' do
      context 'when the xpack role is on everything' do
        xpack_tag_context true, true, true, true, true
      end
    end
  end

  context 'for README.asciidoc' do
    convert_single_before_context do |src|
      root = File.expand_path('../../', __dir__)
      images = ['cat.jpg', 'chunking-toc.png', 'example.svg', 'screenshot.png']
      images.each do |img|
        src.cp "#{root}/resources/readme/#{img}", "resources/readme/#{img}"
      end
      src.copy_shared_conf
      txt = File.open("#{root}/README.asciidoc", 'r:UTF-8', &:read)
      src.write 'index.asciidoc', txt
    end
    page_context 'index.html' do
      it 'has the right title' do
        expect(title).to eq('Docs HOWTO')
      end
    end
    page_context '_conditions_of_use.html' do
      it 'has the right title' do
        expect(title).to eq('Conditions of use')
      end
    end
    page_context 'setup.html' do
      it 'has the right title' do
        expect(title).to eq('Getting started')
      end
    end
    page_context 'build.html' do
      it 'has the right title' do
        expect(title).to eq('Building documentation')
      end
    end
    page_context 'asciidoc-guide.html' do
      it 'has the right title' do
        expect(title).to eq('Asciidoc Guide')
      end
    end
    page_context 'images.html' do
      it 'has the right title' do
        expect(title).to eq('Images')
      end
      it 'has the cat image with a title' do
        expect(body).to include <<~HTML
          <div id="cat" class="imageblock">
          <div class="content">
          <img src="resources/readme/cat.jpg" alt="Alt text">
          </div>
          <div class="title">Figure 1. A scaredy cat</div>
          </div>
        HTML
      end
      it 'has the cat image with specified width and without a title' do
        expect(body).to include <<~HTML
          <div id="cat" class="imageblock">
          <div class="content">
          <img src="resources/readme/cat.jpg" alt="Alt text">
          </div>
        HTML
      end
      it 'has the screenshot' do
        expect(body).to include <<~HTML
          <div class="imageblock screenshot">
          <div class="content">
          <img src="resources/readme/screenshot.png" alt="A screenshot example">
          </div>
          </div>
        HTML
      end
    end
    page_context 'chunking.html' do
      it 'has the right title' do
        expect(title).to eq('Controlling chunking')
      end
      it 'has the chunking image' do
        expect(body).to include <<~HTML
          <div class="imageblock">
          <div class="content">
          <img src="resources/readme/chunking-toc.png" alt="TOC screenshot">
          </div>
          </div>
        HTML
      end
    end
    # NOTE: There are lots more pages but it probably isn't worth asserting
    # on them too.
    file_context 'snippets/1.console' do
      let(:expected) do
        <<~CONSOLE
          GET /_search
          {
              "query": "foo bar"
          }
        CONSOLE
      end
      it 'has the right content' do
        expect(contents).to eq(expected)
      end
    end
    file_context 'resources/readme/cat.jpg'
    file_context 'resources/readme/chunking-toc.png'
    file_context 'resources/readme/screenshot.png'
  end

  context 'for a book with console alternatives' do
    def self.index
      <<~ASCIIDOC
        = Title

        [[chapter]]
        == Chapter
        #{ConsoleExamples::README_LIKE}
      ASCIIDOC
    end
    convert_before do |src, dest|
      repo = src.repo 'src'
      from = repo.write 'index.asciidoc', index
      repo.commit 'commit outstanding'
      # Points java to a directory without any examples so we can report that.
      convert = dest.prepare_convert_single(from, '.')
                    .alternatives(
                      'console', 'js', "#{__dir__}/../readme_examples/js"
                    )
                    .alternatives(
                      'console', 'csharp',
                      "#{__dir__}/../readme_examples/csharp"
                    )
                    .alternatives('console', 'java', "#{__dir__}/helper")
      convert.convert
    end
    include_examples 'README-like console alternatives', 'raw', '.'
  end

  context 'for a book with an -extra-title-page.html file' do
    INDEX_BODY = <<~ASCIIDOC
      = Title

      [[section]]
      == Section
    ASCIIDOC
    context 'single page' do
      def self.setup(index_name)
        convert_before do |src, dest|
          repo = src.repo 'src'
          from = repo.write index_name, INDEX_BODY
          repo.write 'index-extra-title-page.html', '<p>extra!</p>'
          repo.commit 'commit outstanding'
          dest.prepare_convert_single(from, '.').single.convert
        end
      end
      shared_examples 'has the extra' do
        file_context 'raw/index.html' do
          it 'contains the extra title page' do
            expect(contents).to include("<div>\n<p>extra!</p>\n</div>")
          end
        end
      end
      context 'when the index is .adoc' do
        setup 'index.adoc'
        include_examples 'has the extra'
      end
      context 'when the index is .asciidoc' do
        setup 'index.asciidoc'
        include_examples 'has the extra'
      end
      context 'when the index is .x.asciidoc' do
        setup 'index.x.asciidoc'
        include_examples 'has the extra'
      end
    end
    context 'multipage' do
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = repo.write 'index.adoc', INDEX_BODY
        repo.write 'index-extra-title-page.html', '<p>extra!</p>'
        repo.commit 'commit outstanding'
        dest.prepare_convert_single(from, '.').convert
      end
      file_context 'raw/index.html' do
        it 'contains the extra title page' do
          expect(contents).to include("<div>\n<p>extra!</p>\n</div>")
        end
        it 'still contains the TOC' do
          expect(contents).to include('START_TOC')
          expect(contents).to include('<div class="toc">')
        end
      end
      file_context 'raw/section.html' do
        it "doesn't contain the extra title page" do
          expect(contents).not_to include("<div>\n<p>extra!</p>\n</div>")
        end
      end
    end
  end
  context 'for a book with a -custom-title-page.html file' do
    INDEX_BODY = <<~ASCIIDOC
      = Title

      [[section]]
      == Section
    ASCIIDOC
    context 'built as a single page' do
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = repo.write 'index.asciidoc', INDEX_BODY
        repo.write 'index-custom-title-page.html', '<h1>My Custom Header</h1>'
        repo.commit 'commit outstanding'
        dest.prepare_convert_single(from, '.')
            .single.convert(expect_failure: true)
      end
      it 'prints an error message about being incompatible' do
        expect(outputs[0]).to include(<<~LOG.strip)
          Using a custom title page is incompatible with --single
        LOG
      end
    end
    context 'multipage' do
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = repo.write 'index.adoc', INDEX_BODY
        repo.write 'index-custom-title-page.html', '<h1>My Custom Header</h1>'
        repo.commit 'commit outstanding'
        dest.prepare_convert_single(from, '.').convert
      end
      file_context 'raw/index.html' do
        it 'contains the custom header' do
          expect(contents).to include('<h1>My Custom Header</h1>')
        end
        it 'does not contain the table of contents' do
          expect(contents).not_to include('START_TOC')
          expect(contents).not_to include('<div class="toc">')
        end
      end
      file_context 'raw/section.html' do
        it 'does not contain the custom header' do
          expect(contents).not_to include('My Custom Header')
        end
      end
    end
    context 'and a -extra-title-page.html file' do
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = repo.write 'index.adoc', INDEX_BODY
        repo.write 'index-custom-title-page.html', '<h1>My Custom Header</h1>'
        repo.write 'index-extra-title-page.html', '<h1>My Extra Header</h1>'
        repo.commit 'commit outstanding'
        dest.prepare_convert_single(from, '.').convert(expect_failure: true)
      end
      it 'prints an error about both files existing' do
        expect(outputs[0]).to include(<<~LOG.strip)
          Cannot have both custom and extra title pages for the same source file
        LOG
      end
    end
  end
  context 'for a book with page-header.html' do
    context 'single page' do
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = repo.write 'index.adoc', <<~ASCIIDOC
          = Title

          [[section]]
          == Section

          Words.
        ASCIIDOC
        repo.write 'page_header.html', '<p>header</p>'
        repo.commit 'commit outstanding'
        dest.prepare_convert_single(from, '.').single.convert
      end
      file_context 'raw/index.html' do
        it 'should contain the header' do
          expect(contents).to include '<p>header</p>'
        end
      end
    end
    context 'multipage' do
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = repo.write 'index.adoc', <<~ASCIIDOC
          = Title

          [[section]]
          == Section

          Words.
        ASCIIDOC
        repo.write 'page_header.html', '<p>header</p>'
        repo.commit 'commit outstanding'
        dest.prepare_convert_single(from, '.').convert
      end
      file_context 'raw/index.html' do
        it 'should contain the header' do
          expect(contents).to include '<p>header</p>'
        end
      end
      file_context 'raw/section.html' do
        it 'should contain the header' do
          expect(contents).to include '<p>header</p>'
        end
      end
    end
    context 'with chinese text' do
      # We've failed in the past on Chinese text with encoding issues.
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = repo.write 'index.adoc', <<~ASCIIDOC
          = Title

          [[section]]
          == Section

          Words.
        ASCIIDOC
        repo.write 'page_header.html', '<p>请注意</p>'
        repo.commit 'commit outstanding'
        dest.prepare_convert_single(from, '.').convert
      end
      file_context 'raw/index.html' do
        it 'should contain the header' do
          expect(contents).to include '<p>请注意</p>'
        end
      end
      file_context 'raw/section.html' do
        it 'should contain the header' do
          expect(contents).to include '<p>请注意</p>'
        end
      end
    end
  end

  context 'for a book that uses {source_branch}' do
    INDEX = <<~ASCIIDOC
      = Title

      [[chapter]]
      == Chapter
      The branch is {source_branch}.
    ASCIIDOC
    def self.convert_with_source_branch_before_context(branch)
      convert_single_before_context do |src|
        unless branch == 'master'
          src.write 'dummy', 'needed so git is ok with switching branches'
          src.commit 'dummy'
          src.switch_to_new_branch branch
        end
        src.write 'index.asciidoc', INDEX
      end
    end
    shared_examples 'contains branch' do |branch|
      page_context 'chapter.html' do
        it 'contains the branch name' do
          expect(body).to include("The branch is #{branch}.")
        end
      end
    end
    context 'when the branch is master' do
      convert_with_source_branch_before_context 'master'
      include_examples 'contains branch', 'master'
    end
    context 'when the branch is 7.x' do
      convert_with_source_branch_before_context '7.x'
      include_examples 'contains branch', '7.x'
    end
    context 'when the branch is 1.5' do
      convert_with_source_branch_before_context '1.5'
      include_examples 'contains branch', '1.5'
    end
    context 'when the branch is 18.5' do
      convert_with_source_branch_before_context '18.5'
      include_examples 'contains branch', '18.5'
    end
    context 'when the branch is some_crazy_thing' do
      convert_with_source_branch_before_context 'some_crazy_thing'
      include_examples 'contains branch', 'master'
    end
    context 'when the branch is some_crazy_thing_7.x' do
      convert_with_source_branch_before_context 'some_crazy_thing_7.x'
      include_examples 'contains branch', '7.x'
    end
    context 'when the branch is some_crazy_thing_7_x' do
      convert_with_source_branch_before_context 'some_crazy_thing_7_x'
      include_examples 'contains branch', '7_x'
    end
  end

  context 'when run with --open' do
    include_context 'source and dest'
    before(:context) do
      repo = @src.repo_with_index 'repo', 'Words'
      @opened_docs =
        @dest.prepare_convert_single("#{repo.root}/index.asciidoc", '.').open
    end
    after(:context) do
      @opened_docs.exit
    end

    let(:root) { 'http://localhost:8000/guide' }
    let(:static) { "#{root}/static" }
    let(:index) { Net::HTTP.get_response(URI("#{root}/index.html")) }
    let(:air_gapped_index) do
      uri = URI("#{root}/index.html")
      req = Net::HTTP::Get.new(uri)
      req['Host'] = 'gapped.localhost'
      Net::HTTP.start(uri.hostname, uri.port, read_timeout: 20) do |http|
        http.request(req)
      end
    end
    let(:toc) { Net::HTTP.get_response(URI("#{root}/toc.html")) }
    let(:js) do
      Net::HTTP.get_response(URI("#{static}/docs.js"))
    end
    let(:jquery) do
      Net::HTTP.get_response(URI("#{static}/jquery.js"))
    end
    let(:css) do
      Net::HTTP.get_response(URI("#{static}/styles.css"))
    end

    include_examples 'the root'
    include_examples 'the favicon'

    context 'the index' do
      context 'when not air gapped' do
        it 'contains the gtag js' do
          expect(index).to serve(include(<<~HTML.strip))
            https://www.googletagmanager.com/gtag/js
          HTML
        end
        it 'serves the chapter header' do
          expect(index).to serve(doc_body(include(<<~HTML.strip)))
            <a href="chapter.html">Chapter
          HTML
        end
      end
      context 'when air gapped' do
        it "doesn't contain the gtag js" do
          expect(air_gapped_index).not_to serve(include(<<~HTML.strip))
            https://www.googletagmanager.com/gtag/js
          HTML
        end
        it 'serves the chapter header' do
          expect(air_gapped_index).to serve(doc_body(include(<<~HTML.strip)))
            <a href="chapter.html">Chapter
          HTML
        end
      end
    end
    context 'the table of contents' do
      it "isn't templated" do
        expect(toc).to serve(start_with('<div class="toc">'))
      end
    end

    context 'the js' do
      it 'is unminified' do
        expect(js).to serve(include(<<~JS))
          // Test comment used to detect unminifed JS in tests
        JS
      end
      it 'include hot module replacement for the css' do
        expect(js).to serve(include(<<~JS))
          // Setup hot module replacement for css if we're in dev mode.
        JS
      end
      it 'includes a source map' do
        expect(js).to serve(include('sourceMappingURL='))
      end
    end
    context 'jquery' do
      it 'is unminified' do
        # This comment is a little brittle to detect but I don't expect us to
        # rely on jquery forever.
        expect(jquery).to serve(include(<<~JS))
          Includes Sizzle.js
        JS
      end
      it "doesn't include a source map" do
        expect(jquery).not_to serve(include('sourceMappingURL='))
      end
    end
    context 'the css' do
      it 'is unminified' do
        expect(css).to serve(include(<<~CSS))
          /* test comment used to detect unminified source */
        CSS
      end
      it 'includes a source map' do
        expect(css).to serve(include('sourceMappingURL='))
      end
    end
  end

  ##
  # When you point `build_docs` to a worktree it doesn't properly share the
  # worktree's parent into the docker container. This test simulates *that*.
  context 'when building a book in a worktree without its parent' do
    convert_before do |src, dest|
      repo = src.repo_with_index 'src', <<~ASCIIDOC
        I am in a worktree.
      ASCIIDOC
      worktree = src.path 'worktree'
      repo.create_worktree worktree, 'HEAD'
      FileUtils.rm_rf repo.root
      dest.prepare_convert_single("#{worktree}/index.asciidoc", '.')
          .convert
    end
    page_context 'chapter.html' do
      it 'complains about not being able to find the repo toplevel' do
        expect(outputs[0]).to include("Couldn't find repo toplevel for /tmp/")
      end
      it 'has the worktree text' do
        expect(body).to include('I am in a worktree.')
      end
    end
  end

  context 'when a book contains migration warnings' do
    shared_context 'convert with migration warnings' do |suppress|
      convert_before do |src, dest|
        repo = src.repo_with_index 'src', <<~ASCIIDOC
          --------
          CODE HERE
          ----
        ASCIIDOC
        c = dest.prepare_convert_single("#{repo.root}/index.asciidoc", '.')
        c.suppress_migration_warnings if suppress
        c.convert(expect_failure: !suppress)
      end
    end
    context 'and they are not suppressed' do
      include_context 'convert with migration warnings', false
      it 'fails with an appropriate error status' do
        expect(statuses[0]).to eq(255)
      end
      it 'complains about the MIGRATION warning' do
        expect(outputs[0]).to include(<<~LOG)
          asciidoctor: WARNING: index.asciidoc: line 7: MIGRATION: code block end doesn't match start
        LOG
      end
    end
    context 'and they are suppressed' do
      include_context 'convert with migration warnings', true
      it "doesn't complain about the MIGRATION warning" do
        expect(outputs[0]).not_to include(<<~LOG)
          asciidoctor: WARNING: index.asciidoc: line 7: MIGRATION: code block end doesn't match start
        LOG
      end
      page_context 'chapter.html' do
        it 'contains the snippet' do
          expect(body).to include('CODE HERE')
        end
      end
    end
  end

  context 'when an included file is missing' do
    convert_before do |src, dest|
      repo = src.repo_with_index 'src', <<~ASCIIDOC
        include::missing.asciidoc[]
      ASCIIDOC
      dest.prepare_convert_single("#{repo.root}/index.asciidoc", '.')
          .convert(expect_failure: true)
    end
    it 'fails with an appropriate error status' do
      expect(statuses[0]).to eq(255)
    end
    it 'logs the missing file' do
      expect(outputs[0]).to include(<<~LOG.strip)
        ERROR: index.asciidoc: line 5: include file not found: #{@src.repo('src').root}/missing.asciidoc
      LOG
    end
  end
  context 'when a referenced id is missing' do
    convert_before do |src, dest|
      repo = src.repo_with_index 'src', <<~ASCIIDOC
        <<missing-ref>>
      ASCIIDOC
      dest.prepare_convert_single("#{repo.root}/index.asciidoc", '.')
          .convert(expect_failure: true)
    end
    it 'fails with an appropriate error status' do
      expect(statuses[0]).to eq(255)
    end
    it 'logs the file that contains the missing include' do
      expect(outputs[0]).to include(<<~LOG.strip)
        asciidoctor: WARNING: invalid reference: missing-ref
      LOG
    end
  end
end
