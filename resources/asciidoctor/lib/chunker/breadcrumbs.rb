# frozen_string_literal: true

require_relative 'link'
require_relative 'search_breadcrumbs'
require_relative 'obs_breadcrumbs'

module Chunker
  ##
  # Builds the "breadcrumbs" at the top of the page.
  module Breadcrumbs
    include Link
    include SearchBreadcrumbs
    include ObsBreadcrumbs

    def generate_breadcrumbs(doc, section)
      chev = <<~HTML.strip
        <span class="chevron-right">/</span>
      HTML
      result = ['<div class="breadcrumbs">']
      result += generate_breadcrumb_links(section, chev).reverse
      result << '</div>'

      update_breadcrumbs_cases(result, chev, doc)

      Asciidoctor::Block.new doc, :pass, source: result.join("\n")
    end

    def update_breadcrumbs_cases(result, chev, doc)
      cases = {
        'APM' => 'generate_apm_breadcrumbs',
        'ECS Logging' => 'generate_ecslogging_breadcrumbs',
        'Enterprise Search' => 'generate_search_breadcrumbs',
        'App Search' => 'generate_search_breadcrumbs',
        'Workplace Search' => 'generate_search_breadcrumbs',
      }

      cases.each do |c, method|
        next unless result[2].to_s.include?(c)

        result = result[2] = if method == 'generate_search_breadcrumbs'
                               chev + send(method, doc, c)
                             else
                               chev + send(method, doc)
                             end
        break
      end
    end

    def generate_breadcrumb_links(section, chev)
      result = []
      parent = section
      while (parent = parent.parent)
        extra = parent.context == :document ? parent.attr('title-extra') : ''
        link = <<~HTML.strip
          <span class="breadcrumb-link"><a #{link_href parent}>#{parent.title}#{extra}</a></span>
        HTML
        links = chev + link
        result << links
      end
      result << <<~HTML.strip
        <span class="breadcrumb-link"><a href="/guide/">Elastic Docs</a></span>
      HTML
      result
    end
  end
end
