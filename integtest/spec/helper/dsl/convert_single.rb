# frozen_string_literal: true

module Dsl
  module ConvertSingle
    ##
    # Include a context into the current context that converts asciidoc files
    # into html and adds some basic assertions about the conversion process.
    # Pass a block that takes a `Repo` object and returns the "index" asciidoc
    # file to convert. It does the conversion with both with `--asciidoctor`
    # and without `--asciidoctor` and asserts that the files are the same.
    def convert_single_before_context
      include_context 'source and dest'
      before(:context) do
        from = yield @src.repo('src')
        @src.init_repos
        @asciidoctor_out = @dest.convert_single from, '.', asciidoctor: true
        # Convert a second time with the legacy `AsciiDoc` tool and stick the
        # result into the `asciidoc` directory. We will compare the results of
        # this conversion with the results of the `Asciidoctor` conversion.
        @asciidoc_out = @dest.convert_single from, 'asciidoc',
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
        # The only difference should be that the output path
        # includes `asciidoc/`
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
          html_diff = File.expand_path '../../../html_diff', __dir__
          sh "#{html_diff} #{asciidoctor_file} #{asciidoc_file}"
        end
      end
    end
  end
end
