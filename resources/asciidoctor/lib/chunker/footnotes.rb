# frozen_string_literal: true

module Chunker
  ##
  # Generate the footnotes.
  module Footnotes
    def footnotes(doc, subdoc)
      return unless doc.footnotes?

      source = [
        '<div id="footnotes">',
        doc.footnotes.map { |f| doc.converter.convert f, 'footnote' },
        '</div>',
      ].join "\n"
      doc.footnotes.clear

      Asciidoctor::Block.new subdoc, :pass, source: source
    end

    def convert_footnote(footnote)
      <<~HTML.strip
        <div class="footnote" id="_footnotedef_#{footnote.index}">
        <sup>[<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a>]</sup> #{footnote.text}
        </div>
      HTML
    end
  end
end
