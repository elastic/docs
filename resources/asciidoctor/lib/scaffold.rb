# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Scaffolding for TreeProcessor extensions to automatically iterate.
#
class TreeProcessorScaffold < Asciidoctor::Extensions::TreeProcessor
  def process_block(_document)
    raise ::NotImplementedError,
      %(TreeProcessorScaffold subclass must implement ##{__method__} method)
  end

  def process(document)
    process_blocks document
    nil
  end

  def process_blocks(block)
    process_block block
    sub_blocks = block.context == :dlist ? block.blocks.flatten : block.blocks
    sub_blocks.each do |sub_block|
      # subblock can be nil for definition lists without a definition.
      # this is weird, but it is safe to skip nil here because subclasses
      # can't change it anyway.
      process_blocks sub_block if sub_block
    end
  end
end
