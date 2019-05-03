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
      convert_before do |src, dest|
        yield src
        dest.convert_all src.conf
        dest.checkout_conversion
      end
      include_examples 'convert all'
    end

    shared_context 'convert all' do
      let(:out) { outputs[0] }
      include_examples 'builds all books'
      include_examples 'convert all basics'
    end
    shared_examples 'builds all books' do
      it 'prints that it is updating repositories' do
        # TODO: more assertions about the logged output
        expect(out).to include('Updating repositories')
      end
      it 'prints that it is building all branches of every book' do
        # TODO: read branches from somewhere when we specify them
        books.each_value do |book|
          expect(out).to include("#{book.title}: Building master...")
          expect(out).to include("#{book.title}: Finished master")
        end
      end
      it 'prints that it is copying master to current for every book' do
        # TODO: read branches from somewhere when we specify them
        books.each_value do |book|
          expect(out).to include("#{book.title}: Copying master to current")
        end
      end
      it 'prints that it is commiting changes' do
        expect(out).to include('Commiting changes')
      end
      it 'prints that it is pushing changes' do
        expect(out).to include('Pushing changes')
      end
    end
    shared_examples 'convert all basics' do
      it 'creates redirects.conf' do
        expect(dest_file('redirects.conf')).to file_exist
      end
      it 'creates html/branches.yaml' do
        expect(dest_file('html/branches.yaml')).to file_exist
      end
      file_context 'html/revision.txt' do
        it 'contains the latest revision message' do
          expect(contents).to include(latest_revision)
        end
      end
      page_context 'the global index', 'html/index.html' do
        it 'contains a link to the current verion of each book' do
          books.each_value do |book|
            expect(body).to include(book.link_to('current'))
          end
        end
      end
    end
  end
end
