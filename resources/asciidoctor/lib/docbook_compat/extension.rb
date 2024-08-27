# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'
require_relative '../strip_tags'
require_relative 'clear_cached_titles'
require_relative 'convert_admonition'
require_relative 'convert_dlist'
require_relative 'convert_document'
require_relative 'convert_example'
require_relative 'convert_floating_title'
require_relative 'convert_inline_quoted'
require_relative 'convert_links'
require_relative 'convert_listing'
require_relative 'convert_lists'
require_relative 'convert_open'
require_relative 'convert_outline'
require_relative 'convert_paragraph'
require_relative 'convert_quote'
require_relative 'convert_sidebar'
require_relative 'convert_table'
require_relative 'titleabbrev_handler'

##
# HTML5 converter that emulates Elastic's docbook generated html.
module DocbookCompat
  def self.activate(registry)
    return unless registry.document.basebackend? 'html'

    registry.treeprocessor ClearCachedTitles
    registry.treeprocessor TitleabbrevHandler
    DelegatingConverter.setup(registry.document) { |d| Converter.new d }
  end

  ##
  # A Converter implementation that emulates Elastic's docbook generated html.
  class Converter < DelegatingConverter
    include ConvertAdmonition
    include ConvertDList
    include ConvertDocument
    include ConvertExample
    include ConvertFloatingTitle
    include ConvertInlineQuoted
    include ConvertLinks
    include ConvertListing
    include ConvertLists
    include ConvertOpen
    include ConvertOutline
    include ConvertParagraph
    include ConvertQuote
    include ConvertSidebar
    include ConvertTable
    include StripTags

    def convert_section(node)
      <<~HTML
        <div class="#{wrapper_class_for node}#{node.role ? " #{node.role}" : ''}">
        <div class="titlepage"><div><div>
        <div class="position-relative"><h#{hlevel node} class="title"><a id="#{node.id}"></a>#{node.captioned_title}#{xpack_tag node}</h#{hlevel node}>#{node.attr 'edit_me_link', ''}</div>
        </div></div></div>
        #{node.content}
        </div>
      HTML
    end

    def convert_literal(node)
      <<~HTML
        <pre class="literallayout">#{node.content}</pre>
      HTML
    end

    def xpack_tag(node)
      return unless node.roles.include? 'xpack'
      return if (node.document.attr 'hide-xpack-tags') == 'true'

      '<a class="xpack_tag" href="/subscriptions"></a>'
    end

    def hlevel(section)
      # If the heading level is less than 2, use 2,
      # otherwise use the given heading level.
      #
      # This ensures:
      # - There are no `h0`s, which are not valid HTML elements.
      # - There are no `h1`s in the page's main content since
      #   we only want one `h1` per page, and one is generated
      #   automatically and added to the page header (outside
      #   div#content).
      if section.level < 2
        2
      else
        section.level
      end
    end

    SECTION_WRAPPER_CLASSES = %w[part chapter].freeze
    def wrapper_class_for(section)
      wrapper_class = section.attr 'style'
      wrapper_class ||= SECTION_WRAPPER_CLASSES[section.level]
      wrapper_class ||= 'section'
      wrapper_class
    end
  end
end
