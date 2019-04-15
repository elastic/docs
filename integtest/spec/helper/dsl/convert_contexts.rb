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
      context 'when run with asciidoc' do
        let(:asciidoctor_files) do
          files_in(dest_file('.')).reject { |f| f.start_with? 'asciidoc/' }
        end
        let(:asciidoctor_non_snippet_files) do
          asciidoctor_files.reject { |f| File.extname(f) == '.console' }
        end
        let(:asciidoctor_snippet_files) do
          asciidoctor_files.select { |f| File.extname(f) == '.console' }
        end
        let(:asciidoc_files) do
          files_in(dest_file('asciidoc'))
        end
        let(:asciidoc_non_snippet_files) do
          asciidoc_files.reject { |f| File.extname(f) == '.json' }
        end
        let(:asciidoc_snippet_files) do
          asciidoc_files.select { |f| File.extname(f) == '.json' }
        end
        it 'logs the same lines' do
          # The only difference should be that the output path
          # includes `asciidoc/`
          expect(@asciidoc_out.gsub('asciidoc/', '')).to eq(@asciidoctor_out)
        end
        it 'makes the same non-snippet files' do
          expect(asciidoc_non_snippet_files).to contain_exactly(
            *asciidoctor_non_snippet_files
          )
        end
        it 'makes *almost* the same html files' do
          # This does *all* the files in the same example which doesn't feel
          # very rspec but it gets the job done and we don't know the file list
          # at this point so there isn't much we can do about it.
          asciidoctor_files.each do |file|
            next unless File.extname(file) == '.html'

            # We shell out to the html_diff tool that we wrote for this when
            # the integration tests were all defined in a Makefile. It isn't
            # great to shell out here but we've already customized html_diff.
            asciidoctor_file = dest_file(file)
            asciidoc_file = dest_file("asciidoc/#{file}")
            html_diff = File.expand_path '../../../html_diff', __dir__
            sh "#{html_diff} #{asciidoctor_file} #{asciidoc_file}"
          end
        end
        it 'makes exactly the same non-snippet, non-html files' do
          asciidoctor_non_snippet_files.each do |file|
            next if File.extname(file) == '.html'

            asciidoctor_digest = Digest::MD5.file dest_file(file)
            asciidoc_digest = Digest::MD5.file dest_file("asciidoc/#{file}")
            expect(asciidoc_digest).to eq(asciidoctor_digest)
          end
        end
        it 'makes the same snippet files but with different names' do
          asciidoc = {}
          asciidoc_snippet_files.each do |file|
            asciidoc_file = dest_file "asciidoc/#{file}"
            snippet = File.open asciidoc_file, 'r:UTF-8', &:read
            # Strip trailing spaces from the snippet because Asciidoctor
            # does that and AsciiDoc does not.
            snippet = snippet.lines.map(&:rstrip).join("\n")
            # Add a trailing newline to the snippet because Asciidoctor
            # does that and AsciiDoc does not.
            snippet += "\n"
            asciidoc[snippet] = file
          end
          asciidoctor = {}
          asciidoctor_snippet_files.each do |file|
            snippet = File.open(dest_file(file), 'r:UTF-8', &:read)
            asciidoctor[snippet] = file
          end
          expect(asciidoc).to have_same_keys(asciidoctor)
        end
      end
    end
  end
end
