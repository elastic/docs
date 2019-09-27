# frozen_string_literal: true

module Dsl
  module ConvertAll
    ##
    # Include a context into the current context that converts "all books" as
    # configured by a conf file. Pass a block that takes a `Source` object and
    # uses it to:
    # 1. Create source repositories and write them
    # 2. Configure the books that should be built
    def convert_all_before_context(relative_conf: false, target_branch: nil)
      convert_before do |src, dest|
        yield src
        dest.convert_all src.conf(relative_path: relative_conf),
                         target_branch: target_branch
        dest.checkout_conversion branch: target_branch
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
      include_examples 'commits changes'
    end
    shared_examples 'commits changes' do
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
      page_context 'the global index', 'html/index.html' do
        it 'contains a link to the current verion of each book' do
          books.each_value do |book|
            expect(body).to include(book.link_to('current'))
          end
        end
      end
      file_context 'html/static/docs.js' do
        it 'is minified' do
          expect(contents).to include(<<~JS.strip)
            return a&&a.__esModule?{d:a.default}:{d:a}
          JS
        end
        it "doesn't include a source map" do
          expect(contents).not_to include('sourceMappingURL=')
        end
      end
      file_context 'html/static/jquery.js' do
        it 'is minified' do
          expect(contents).to include(<<~JS.strip)
            /*! jQuery v1.12.4 | (c) jQuery Foundation | jquery.org/license */
          JS
        end
        it "doesn't include a source map" do
          expect(contents).not_to include('sourceMappingURL=')
        end
      end
      file_context 'html/static/styles.css' do
        it 'is minified' do
          expect(contents).to include(<<~CSS.strip)
            *{font-family:Inter,sans-serif}
          CSS
        end
        it "doesn't include a source map" do
          expect(contents).not_to include('sourceMappingURL=')
        end
      end
    end
  end
end
