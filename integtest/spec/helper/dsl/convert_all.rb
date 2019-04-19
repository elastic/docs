# frozen_string_literal: true

require_relative 'source'

module Dsl
  module ConvertAll
    ##
    # Include a context into the current context that converts "all books" as
    # configured by a conf file. Pass a block that takes a `Source` object,
    # writes all of the input asciidoc files, writes the conf file, and returns
    # the path to the conf file.
    def convert_all_before_context
      include_context 'tmp dirs'
      before(:context) do
        source = Source.new @src
        from = yield source
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
