# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'
require_relative 'convert_admonition'
require_relative 'convert_document'
require_relative 'convert_dlist'
require_relative 'convert_links'
require_relative 'convert_listing'
require_relative 'convert_lists'
require_relative 'convert_open'
require_relative 'convert_outline'
require_relative 'convert_table'
require_relative 'titleabbrev_handler'

##
# HTML5 converter that emulates Elastic's docbook generated html.
module DocbookCompat
  def self.activate(registry)
    return unless registry.document.basebackend? 'html'

    registry.treeprocessor TitleabbrevHandler
    DelegatingConverter.setup(registry.document) { |d| Converter.new d }
  end

  ##
  # A Converter implementation that emulates Elastic's docbook generated html.
  class Converter < DelegatingConverter
    include ConvertAdmonition
    include ConvertDocument
    include ConvertDList
    include ConvertLinks
    include ConvertListing
    include ConvertLists
    include ConvertOpen
    include ConvertOutline
    include ConvertTable

    def convert_section(node)
      <<~HTML
        <div class="#{wrapper_class_for node}#{node.role ? " #{node.role}" : ''}">
        <div class="titlepage"><div><div>
        <h#{hlevel node} class="title"><a id="#{node.id}"></a>#{node.captioned_title}#{node.attr 'edit_me_link', ''}#{xpack_tag node}</h#{hlevel node}>
        </div></div></div>
        #{node.content}
        </div>
      HTML
    end

    def convert_floating_title(node)
      tag_name = %(h#{node.level + 1})
      # Asciidoctor's standard is to put the id on the header tag but docbook
      # puts it in its own anchor tag.
      anchor = node.id ? %(<a id="#{node.id}"></a>) : ''
      classes = [node.role].compact
      classes_html = classes.empty? ? '' : " class=#{classes.join ' '}"
      <<~HTML
        <#{tag_name}#{classes_html}>#{anchor}#{node.title}#{node.attr 'edit_me_link', ''}#{xpack_tag node}</#{tag_name}>
      HTML
    end

    def convert_paragraph(node)
      # Asciidoctor adds a \n at the end of the paragraph so we don't.
      %(<p>#{paragraph_id_part node}#{node.content}</p>)
    end

    def paragraph_id_part(node)
      return if node.id.nil? || node.id.empty?

      %(<a id="#{node.id}"></a>)
    end

    def convert_inline_quoted(node)
      case node.type
      when :monospaced
        node.attributes['role'] ||= 'literal'
        yield
      when :strong
        # Docbook's "strong" rendering is comically repetitive.....
        %(<span class="strong strong"><strong>#{node.text}</strong></span>)
      else
        yield
      end
    end

    def convert_literal(node)
      <<~HTML
        <pre class="literallayout">#{node.content}</pre>
      HTML
    end

    def convert_sidebar(node)
      result = [%(<div class="sidebar#{node.role ? " #{node.role}" : ''}">)]
      if node.title
        result << '<div class="titlepage"><div><div>'
        result << %(<p class="title"><strong>#{node.title}</strong></p>)
        result << %(</div></div></div>)
      else
        result << '<div class="titlepage"></div>'
      end
      result += [node.content, '</div>']
      result.join "\n"
    end

    def xpack_tag(node)
      return unless node.roles.include? 'xpack'

      '<a class="xpack_tag" href="/subscriptions"></a>'
    end

    def hlevel(section)
      # Walk up the ancestry until the ancestor's parent is the document. The
      # ancestor that we end up with is the "biggest" section containing this
      # section. Except don't walk *all* the way. Because docbook doesn't.
      # See that `unless` below? If we were walking it should be `until` but
      # docbook *doesn't* walk. It just does this. Why? Ghosts maybe. I dunno.
      # But we're trying to emulate docbook. So here we are.
      ancestor = section
      ancestor = ancestor.parent unless ancestor.parent.context == :document
      # If *that* section is level 0 then we have to bump the hlevel of our
      # section by one. The argument for this goes: we have to bump the level 0
      # section's hlevel by one anyway because there *isn't* an h0 tag. So we
      # have to bump all of its children.
      section.level + (ancestor.level.zero? ? 1 : 0)
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
