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
      result << '</div>'
      Asciidoctor::Block.new doc, :pass, source: result.join("\n")
    end

    def generate_breadcrumb_links(section)
      result = []
      parent = section
      first = true
      while (parent = parent.parent)
        extra = parent.context == :document ? parent.attr('title-extra') : ''
        first_link = <<~HTML.strip
          <span class="breadcrumb-link"><a #{link_href parent}>#{parent.title}#{extra}</a></span>
        HTML
        next_links = first_link + <<~HTML.strip
          <span class="chevron-right">›</span>
        HTML
        # This prevents a chevron from being placed after the last breadcrumb
        links = first == true ? first_link : next_links
        result << links
        first = false
      end
      result << <<~HTML.strip
        <span class="breadcrumb-link"><a href="/guide/">Docs home</a></span><span class="chevron-right">›</span>
      HTML
      result
    end
  end
end
