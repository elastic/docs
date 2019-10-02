# frozen_string_literal: true

require 'net/http'

require_relative 'dsl/convert_all'
require_relative 'dsl/convert_single'
require_relative 'dsl/file_contexts'

##
# Defines methods to create contexts and shared examples used in the tests.
module Dsl
  ##
  # Setup some conversion that runs before this context. Prefer
  # convert_all_before_context if you need to test `--all` once and prefer
  # convert_single_before_context if you need to test `--doc`. Use this
  # directly only if you need to test `--all` multiple times.
  def convert_before
    include_context 'source and dest'
    before(:context) do
      yield @src, @dest
    end
  end

  RSpec.shared_context 'source and dest' do
    before(:context) do
      @tmp = Dir.mktmpdir
      @src = Source.new @tmp
      @dest = Dest.new @tmp
    end

    after(:context) do
      FileUtils.remove_entry @tmp
    end

    let(:src) { @src }
    let(:books) { @src.books }
    let(:outputs) { @dest.convert_outputs }
    let(:statuses) { @dest.convert_statuses }

    ##
    # Build a path to a file in the destination.
    def dest_file(file)
      @dest.path(file)
    end
  end

  RSpec.shared_examples 'the root' do
    context 'the root' do
      let(:root) do
        Net::HTTP.get_response(URI('http://localhost:8000/'))
      end
      it 'redirects to the guide root' do
        expect(root.code).to eq('301')
        expect(root['Location']).to eq('http://localhost:8000/guide/index.html')
      end
    end
  end
  RSpec.shared_examples 'the favicon' do
    context 'the favicon' do
      let(:favicon) do
        Net::HTTP.get_response(URI('http://localhost:8000/favicon.ico'))
      end
      let(:path) { '/docs_build/resources/web/static/favicon.ico' }
      let(:expected_bits) { File.open dest_file(path), 'rb', &:read }
      it 'serves the favicon' do
        expect(favicon).to serve(eq(expected_bits))
      end
    end
  end

  include ConvertAll
  include ConvertSingle
  include FileContexts
end
