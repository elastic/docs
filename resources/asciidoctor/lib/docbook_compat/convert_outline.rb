# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert the table of contents.
  module ConvertOutline
    def convert_outline(node, opts = {})
      # Asciidoctor's implementation looks lovely but doesn't match docbook's
      # implementation. So we drop our own in. We should see if we can use
      # Asciidoctor's implementation ASAP though.
      toclevels = opts[:toclevels] || node.document.attributes['toclevels'].to_i
      result = [%(<ul class="toc">)]
      result += node.sections.map { |s| outline_section s, toclevels }
      result << '</ul>'
      result.join "\n"
    end

    def outline_section(section, toclevels)
      link = %(<a href="##{section.id}">#{section.title}</a>)
      link = %(<span class="#{wrapper_class_for section}">#{link}</span>)
      result = [%(<li>#{link})]
      if section.level < toclevels && section.sections?
        result << '<ul>'
        result += section.sections.map { |s| outline_section s, toclevels }
        result << '</ul>'
      end
      result << '</li>'
      result
    end
  end
end
