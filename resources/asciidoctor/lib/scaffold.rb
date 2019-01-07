require 'asciidoctor/extensions'

include Asciidoctor

##
# Scaffolding for TreeProcessor extensions to automatically iterate.
class TreeProcessorScaffold < Extensions::TreeProcessor
  def process_block document
    raise ::NotImplementedError, %(TreeProcessorScaffold subclass must implement ##{__method__} method)
  end

  def process document
    process_blocks document
    nil
  end

  def process_blocks block
    process_block block
    for subblock in block.context == :dlist ? block.blocks.flatten : block.blocks
      process_blocks subblock
    end
  end
end
