# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative 'doc_munging'
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
    include DocMunging

    def initialize(delegate)
      super(delegate)
    end

    def convert_document(doc)
      html = yield
      html.gsub!(/<html lang="[^"]+">/, '<html>') ||
        raise("Coudn't fix html in #{html}")
      munge_head doc, html
      munge_body doc, html
      munge_title doc, html
      html
    end

    SECTION_WRAPPER_CLASSES = %w[unused chapter section].freeze
    def convert_section(node)
      wrapper_class = SECTION_WRAPPER_CLASSES[node.level] || "sect#{node.level}"
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
      id_attribute = node.id ? %( id="#{node.id}") : ''
      classes = [node.style, node.role].compact
      <<~HTML
        <#{tag_name}#{id_attribute} class="#{classes.join ' '}">#{node.title}#{node.attr 'edit_me_link', ''}</#{tag_name}>
      HTML
    end

    def convert_paragraph(node)
      <<~HTML
        <p>#{node.content}</p>
      HTML
    end

    def convert_inline_anchor(node)
      node.attributes['role'] = 'ulink'
      node.attributes['window'] ||= '_top'
      yield
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
      node.attributes['role'] ||= 'literal'
      yield
    end
  end
end
