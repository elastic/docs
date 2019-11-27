# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'
require_relative 'convert_document'
require_relative 'convert_links'
require_relative 'convert_listing'
require_relative 'convert_lists'
require_relative 'convert_open'
require_relative 'convert_outline'

##
# HTML5 converter that emulates Elastic's docbook generated html.
module DocbookCompat
  def self.activate(registry)
    return unless registry.document.basebackend? 'html'

    DelegatingConverter.setup(registry.document) { |d| Converter.new d }
  end

  ##
  # A Converter implementation that emulates Elastic's docbook generated html.
  class Converter < DelegatingConverter
    include ConvertDocument
    include ConvertLinks
    include ConvertListing
    include ConvertLists
    include ConvertOpen
    include ConvertOutline

    def convert_section(node)
      <<~HTML
        <div class="#{wrapper_class_for node}#{node.role ? " #{node.role}" : ''}">
        <div class="titlepage"><div><div>
        <h#{node.level} class="title"><a id="#{node.id}"></a>#{node.title}#{node.attr 'edit_me_link', ''}</h#{node.level}>
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
        <#{tag_name}#{classes_html}>#{anchor}#{node.title}#{node.attr 'edit_me_link', ''}</#{tag_name}>
      HTML
    end

    def convert_paragraph(node)
      <<~HTML
        <p>#{node.content}</p>
      HTML
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

    def convert_admonition(node)
      name = node.attr 'name'
      <<~HTML
        <div class="#{name} admon">
        <div class="icon"></div>
        <div class="admon_content">
        <p>
        #{node.content}
        </p>
        </div>
        </div>
      HTML
    end

    def convert_literal(node)
      <<~HTML
        <pre class="literallayout">#{node.content}</pre>
      HTML
    end

    def convert_sidebar(node)
      <<~HTML
        <div class="sidebar#{node.role ? " #{node.role}" : ''}">
        <div class="titlepage"><div><div>
        <p class="title"><strong>#{node.title}</strong></p>
        </div></div></div>
        #{node.content}
        </div>
      HTML
    end

    SECTION_WRAPPER_CLASSES = %w[part chapter section].freeze
    def wrapper_class_for(section)
      wrapper_class = section.attr 'style'
      wrapper_class ||= SECTION_WRAPPER_CLASSES[section.level]
      wrapper_class ||= "sect#{section.level}"
      wrapper_class
    end
  end
end
