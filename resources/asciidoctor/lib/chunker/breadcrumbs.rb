# frozen_string_literal: true

require_relative 'link'

module Chunker
  ##
  # Builds the "breadcrumbs" at the top of the page.
  module Breadcrumbs
    include Link

    def generate_breadcrumbs(doc, section)
      result = ['<div class="breadcrumbs">']
      result += generate_breadcrumb_links(section).reverse
      result << %(<span class="breadcrumb-node">#{section.title}</span>)
      result << '</div>'
      Asciidoctor::Block.new doc, :pass, source: result.join("\n")
    end

    def generate_breadcrumb_links(section)
      result = []
      parent = section
      while (parent = parent.parent)
        result << <<~HTML.strip
          <span class="breadcrumb-link"><a #{link_href parent}>#{link_text parent}</a></span>
          »
        HTML
      end
      result
    end
  end
end
