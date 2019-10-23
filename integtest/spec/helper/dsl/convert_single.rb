# frozen_string_literal: true

require 'digest'

module Dsl
  module ConvertSingle
    ##
    # Include a context into the current context that converts asciidoc files
    # into html and adds some basic assertions about the conversion process.
    # Pass a block that takes a `Repo` object and uses it to build and return
    # an index file to convert.
    def convert_single_before_context
      convert_before do |src, dest|
        repo = src.repo 'src'
        from = yield repo
        repo.commit 'commit outstanding'
        dest.convert_single from, '.'
      end
      include_examples 'convert single'
    end
    shared_context 'convert single' do
      let(:out) { outputs[0] }
      it 'prints the "Done" when it is finished' do
        expect(out).to include('Done')
      end
    end
  end
end
