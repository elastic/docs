# frozen_string_literal: true

require_relative '../scaffold.rb'

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
# Turns
#   [source,js]
#   --------------------------------------------------
#   GET / <1>
#   --------------------------------------------------
#   pass:[// CONSOLE]
#   <1> The count of categories that were matched
#   <2> The categories retrieved
#
# Into
#   [source,console]
#   --------------------------------------------------
#   GET / <1>
#   --------------------------------------------------
#   <1> The count of categories that were matched
#   <2> The categories retrieved
#
class ElasticCompatTreeProcessor < TreeProcessorScaffold
  include Asciidoctor::Logging

  def process_block(block)
    return unless block.context == :listing && block.style == 'source'

    process_subs block
    process_lang_override block
  end

  def process_subs(block)
    return if block.subs.include? :specialcharacters

    # callouts have to come *after* special characters
    had_callouts = block.subs.delete(:callouts)
    block.subs << :specialcharacters
    block.subs << :callouts if had_callouts
  end

  LANG_MAPPING = {
    'AUTOSENSE' => 'sense',
    'CONSOLE' => 'console',
    'KIBANA' => 'kibana',
    'SENSE' => 'sense',
  }.freeze

  def process_lang_override(block)
    # Check if the next block is a marker for the language
    # We don't want block.next_adjacent_block because that'll go "too far"
    # and it has trouble with definition lists.
    my_index = block.parent.blocks.find_index block
    return unless my_index

    next_block = block.parent.blocks[my_index + 1]
    return unless next_block && next_block.context == :paragraph
    return unless next_block.source =~ %r{pass:\[//\s*([^:\]]+)(?::\s*([^\]]+))?\]}

    lang = LANG_MAPPING[$1]
    snippet = $2
    return unless lang # Not a language we handle

    block.set_attr 'language', lang
    block.set_attr 'snippet', snippet

    block.parent.blocks.delete next_block
    block.parent.reindex_sections
  end
end
