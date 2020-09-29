# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Scaffolding for TreeProcessor extensions to automatically iterate.
#
class TreeProcessorScaffold < Asciidoctor::Extensions::TreeProcessor
  def process_block(_document)
    raise ::NotImplementedError,
          %(#{self.class} subclass must implement ##{__method__} method)
  end

  def process(document)
    backup = document.attributes.dup
    process_blocks document
    document.attributes.replace backup
    nil
  end

  def process_blocks(block)
    block.document.playback_attributes block.attributes unless block.document == block

    process_block block
    sub_blocks(block).each do |sub_block|
      # sub_block can be nil for definition lists without a definition.
      # this is weird, but it is safe to skip nil here because subclasses
      # can't change it anyway.
      process_blocks sub_block if sub_block
    end
  end

  def sub_blocks(block)
    if block.context == :dlist
      # If there isn't a definition then the list can have a nil. So we compact.
      block.blocks.flatten.compact
    else
      # Dup so modifications to the list don't cause us to reprocess
      block.blocks.dup
    end
  end
end
