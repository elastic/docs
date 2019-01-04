require_relative '../scaffold.rb'

include Asciidoctor

# TreeProcessor extension to automatically escape special characters in code
# listings and always shift "callouts" after "specialcharacters".
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
#   ["source","java",subs="attributes,macros,specialcharacters,callouts"]
#   --------------------------------------------------
#   long count = response.count(); <1>
#   List<CategoryDefinition> categories = response.categories(); <2>
#   --------------------------------------------------
#   <1> The count of categories that were matched
#   <2> The categories retrieved
#
class ElasticCompatTreeProcessor < TreeProcessorScaffold
  def process_block block
    if block.context == :listing && block.style == "source" &&
          false == block.subs.include?(:specialcharacters)
      # callouts have to come *after* special characters
      had_callouts = block.subs.delete(:callouts)
      block.subs << :specialcharacters
      block.subs << :callouts if had_callouts
    end
  end
end
  