# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert paragraphs.
  module ConvertParagraph
    def convert_paragraph(node)
      # Asciidoctor adds a \n at the end of the paragraph so we don't.
      [
        node.role ? %(<p class="#{node.role}">) : '<p>',
        paragraph_id_part(node),
        paragraph_title_part(node),
        node.content,
        '</p>',
      ].compact.join
    end

    def paragraph_id_part(node)
      return if node.id.nil? || node.id.empty?

      %(<a id="#{node.id}"></a>)
    end

    def paragraph_title_part(node)
      return unless node.title

      "<strong>#{node.title}</strong>"
    end
  end
end
