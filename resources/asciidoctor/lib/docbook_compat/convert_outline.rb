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
      result += node.sections.map { |s| convert_outline_section s, toclevels }
      result << '</ul>'
      result.compact.join "\n"
    end

    private

    def convert_outline_section(section, toclevels)
      return if section.roles.include? 'exclude'

      title = section.attr 'titleabbrev'
      title ||= section.title
      link = %(<a href="##{section.id}">#{title}</a>)
      link = %(<span class="#{wrapper_class_for section}">#{link}</span>)
      [
        %(<li>#{link}),
        convert_outline_subsections(section, toclevels),
        '</li>',
      ].compact
    end

    def convert_outline_subsections(section, toclevels)
      return unless section.level < toclevels && section.sections?

      [
        '<ul>',
        section.sections.map { |s| convert_outline_section s, toclevels },
        '</ul>',
      ].flatten
    end
  end
end
