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

      link = %(<a href="##{section.id}">#{section_link_text section}</a>)
      link = %(<span class="#{wrapper_class_for section}">#{link}</span>)
      [
        %(<li>#{link}),
        convert_outline_subsections(section, toclevels),
        '</li>',
      ].compact
    end

    def section_link_text(section)
      text = section.xreftext nil
      # Normally we won't get an <em> wrapping the text *but* if it was set
      # with something like `reftext=_title_` to make it render properly in
      # in most places then it will have the <em> and we have to remove it.
      text.gsub %r{^<em>(.+)</em>$}, '\\1'
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
