# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert the table of contents.
  module ConvertOutline
    def convert_outline(node)
      # Asciidoctor's implementation looks lovely but doesn't match docbook's
      # implementation. So we drop our own in. We should see if we can use
      # Asciidoctor's implementation ASAP though.
      result = [%(<ul class="toc">\n)]
      node.sections.each do |section|
        result << <<~HTML
          <li><span class="#{wrapper_class_for section}"><a href="##{section.id}">#{section.title}</a></span>
          </li>
        HTML
      end
      result << '</ul>'
      result.join
    end
  end
end
