# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative 'convert_document'
require_relative 'convert_links'
require_relative '../delegating_converter'

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

    def initialize(delegate)
      super(delegate)
    end

    SECTION_WRAPPER_CLASSES = %w[unused chapter section].freeze
    def convert_section(node)
      wrapper_class = node.attr 'style'
      wrapper_class ||= SECTION_WRAPPER_CLASSES[node.level]
      wrapper_class || "sect#{node.level}"
      <<~HTML
        <div class="#{wrapper_class}#{node.role ? " #{node.role}" : ''}">
        <div class="titlepage"><div><div>
        <h#{node.level} class="title"><a id="#{node.id}"></a>#{node.title}#{node.attr 'edit_me_link', ''}</h#{node.level}>
        </div></div></div>
        #{node.content}
        </div>
      HTML
    end

    def convert_floating_title(node)
      tag_name = %(h#{node.level + 1})
      # Asciidoctor's standard is to pu the id on the header tag but docbook
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

    def convert_listing(node)
      lang = node.attr 'language'
      <<~HTML
        <div class="pre_wrapper lang-#{lang}">
        <pre class="programlisting prettyprint lang-#{lang}">#{node.content || ''}</pre>
        </div>
      HTML
    end

    def convert_ulist(node)
      node.style ||= 'itemizedlist'
      node.items.each { |item| item.attributes['role'] ||= 'listitem' }
      html = yield
      node.items.each do |item|
        next unless item.text

        html.sub!("<p>#{item.text}</p>", item.text) ||
          raise("Couldn't remove <p> for #{item.text} in #{html}")
      end
      html
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
  end
end
