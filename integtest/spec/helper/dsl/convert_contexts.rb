# frozen_string_literal: true

require_relative 'source'

module Dsl
  module ConvertContexts
    ##
    # Include a context into the current context that converts asciidoc files
    # into html and adds some basic assertions about the conversion process.
    # Pass a block that takes a `Source` object and returns the "root" asciidoc
    # file to convert. It does the conversion with both with `--asciidoctor`
    # and without `--asciidoctor` and asserts that the files are the same.
    def convert_single_before_context
      include_context 'tmp dirs'
      before(:context) do
        source = Source.new @src
        from = yield source
        source.init_repo '.'
        from = yield(Source.new @src)
        @asciidoctor_out = convert_single from, @dest,
                                          asciidoctor: true
        # Convert a second time with the legacy `AsciiDoc` tool and stick the
        # result into the `asciidoc` directory. We will compare the results of
        # this conversion with the results of the `Asciidoctor` conversion.
        @asciidoc_out = convert_single from, "#{@dest}/asciidoc",
                                       asciidoctor: false
      end
      include_examples 'convert single'
    end
    shared_context 'convert single' do
      let(:out) { @asciidoctor_out }
      let(:asciidoctor_files) do
        files_in(dest_file('.')).reject { |f| f.start_with? 'asciidoc/' }
      end
      let(:asciidoc_files) do
        files_in(dest_file('asciidoc'))
      end
      it 'prints the path to the html index' do
        expect(out).to include(dest_file('index.html'))
      end
      it 'creates the template hash' do
        expect(dest_file('template.md5')).to file_exist
      end
      it 'creates the css' do
        expect(dest_file('styles.css')).to file_exist
      end
      it 'creates the js' do
        expect(dest_file('docs.js')).to file_exist
      end
      it 'logs the same lines with asciidoc' do
        # The only difference should be that the output path includes `asciidoc/`
        expect(@asciidoc_out.gsub('asciidoc/', '')).to eq(@asciidoctor_out)
      end
      it 'makes the same files with asciidoc' do
        expect(asciidoc_files).to eq(asciidoctor_files)
      end
      it 'makes exactly the same html files with asciidoc' do
        # This does *all* the files in the same example which doesn't feel very
        # rspec but it gets the job done and we don't know the file list at this
        # point so there isn't much we can do about it.
        asciidoctor_files.each do |file|
          next unless File.extname(file) == '.html'
  
          # We shell out to the html_diff tool that we wrote for this when the
          # integration tests were all defined in a Makefile. It isn't great to
          # shell out here but we've already customized html_diff.
          asciidoctor_file = dest_file(file)
          asciidoc_file = dest_file("asciidoc/#{file}")
          html_diff = File.expand_path '../../html_diff', __dir__
          sh "#{html_diff} #{asciidoctor_file} #{asciidoc_file}"
        end
      end
    end

    ##
    # Include a context into the current context that converts "all books" as
    # configured by a conf file. Pass a block that takes a `Source` object,
    # writes all of the input asciidoc files, writes the conf file, and returns
    # the path to the conf file.
    def convert_all_before_context
      include_context 'tmp dirs'
      before(:context) do
        from = yield(Source.new @src)
        destbare = File.join @tmp, 'dest.git'
        sh "git init --bare #{destbare}"
        @out = convert_all from, destbare
        sh "git clone #{destbare} #{@dest}"
      end
      include_examples 'convert all'
    end
    shared_context 'convert all' do
      let(:out) { @out }
      let(:dest) { @dest }
      it 'prints that it is updating repositories' do
        # TODO: more assertions about the logged output
        expect(out).to include('Updating repositories')
      end
      it 'creates redirects.conf' do
        expect(dest_file('redirects.conf')).to file_exist
      end
      it 'creates html/branches.yaml' do
        expect(dest_file('html/branches.yaml')).to file_exist
      end
      file_context 'html/revision.txt' do
        it 'contains the initial revision message' do
          expect(contents).to include('init')
        end
      end
      page_context 'the global index', 'html/index.html' do
        it 'contains a link to the test book' do
          expect(body).to include(
            '<a class="ulink" href="test/current/index.html" target="_top">' \
            'Test book</a>'
          )
        end
      end
      page_context 'the book index', 'html/test/index.html' do
        it 'contains a redirect to the only version of the book' do
          expect(body).to include(
            '<meta http-equiv="refresh" content="0; url=current/index.html">'
          )
        end
      end
      page_context "the current version's index",
                   'html/test/current/index.html' do
        it 'contains a table of contents' do
          expect(body).to include('<div class="toc">')
        end
      end
    end
  end
end
