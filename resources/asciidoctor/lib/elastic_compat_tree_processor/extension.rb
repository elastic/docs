require 'asciidoctor/extensions'

include Asciidoctor

# TreeProcessor extension to automatically escape special characters in code
# listings.
#
# Turns
#   ["source","java",subs="attributes,callouts,macros"]
#   --------------------------------------------------
#   long count = response.count(); <1>
#   List<CategoryDefinition> categories = response.categories(); <2>
#   --------------------------------------------------
#   <1> The count of categories that were matched
#   <2> The categories retrieved
#
# Into
#   ["source","java",subs="attributes,callouts,macros,specialcharacters"]
#   --------------------------------------------------
#   long count = response.count(); <1>
#   List<CategoryDefinition> categories = response.categories(); <2>
#   --------------------------------------------------
#   <1> The count of categories that were matched
#   <2> The categories retrieved
#
class ElasticCompatTreeProcessor < Extensions::TreeProcessor
    def process document
      process_blocks document
      nil
    end
  
    def process_blocks block
      if block.context == :listing && block.style == "source"
            false == block.subs.include?(:specialcharacters)
        block.subs << :specialcharacters
      end
      for subblock in block.context == :dlist ? block.blocks.flatten : block.blocks
        process_blocks subblock
      end
    end
  end
  