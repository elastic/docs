# frozen_string_literal: true

require 'digest'

module Dsl
  module ConvertSingle
    ##
    # Include a context into the current context that converts asciidoc files
    # into html and adds some basic assertions about the conversion process.
    # Pass a block that takes a `Repo` object and uses it to build and return
    # an index file to convert. This method will then automatically commit any
    # outstanding changes to the repo and convert the index from asciidoc to
    # html. Twice, actually, once with `--asciidoctor` and once without
    # `--asciidoctor`. Finally this method will include a shared context that
    # asserts some basic things about the built books and that the
    # `--asciidoctor` and non-`--asciidoctor` build produce the same results.
    def convert_single_before_context
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = yield repo
        repo.commit 'commit outstanding'
        dest.convert_single from, '.', asciidoctor: true
        # Convert a second time with the legacy `AsciiDoc` tool and stick the
        # result into the `asciidoc` directory. We will compare the results of
        # this conversion with the results of the `Asciidoctor` conversion.
        dest.convert_single from, 'asciidoc', asciidoctor: false
      end
      include_examples 'convert single'
    end
    shared_context 'convert single' do
      let(:out) { outputs[0] }
      it 'prints the "Done" when it is finished' do
        expect(out).to include('Done')
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
          expect(outputs[1].gsub('asciidoc/', '')).to eq(outputs[0])
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
