# frozen_string_literal: true

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

    let(:books) { @src.books }
    let(:outputs) { @dest.convert_outputs }
    let(:statuses) { @dest.convert_statuses }

    ##
    # Build a path to a file in the destination.
    def dest_file(file)
      @dest.path(file)
    end
  end

  include ConvertAll
  include ConvertSingle
  include FileContexts
end
