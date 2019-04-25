# frozen_string_literal: true

module Dsl
  module ConvertAll
    ##
    # Include a context into the current context that converts "all books" as
    # configured by a conf file. Pass a block that takes a `Source` object and
    # uses it to:
    # 1. Create source repositories and write them
    # 2. Configure the books that should be built
    def convert_all_before_context
      include_context 'source and dest'
      before(:context) do
        yield @src
        @src.init_repos
        @out = @dest.convert_all @src.conf
      end
      include_examples 'convert all'
    end

    shared_context 'convert all' do
      let(:out) { @out }
      let(:books) { @src.books }
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
        it 'contains a link to the current verion of each book' do
          books.each do |book|
            expect(body).to include(book.link_to('current'))
          end
        end
      end
    end
  end
end
