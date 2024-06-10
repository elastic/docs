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

    # Return HTML
    def generate_breadcrumbs(section)
      chev = <<~HTML.strip
        <span class="chevron-right">›</span>
      HTML
      result = <<~HTML.strip
        <div class="breadcrumbs">
      HTML
      result += generate_breadcrumb_links(section, chev)
      result + <<~HTML.strip
        </div>
      HTML
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
      # Add the docs landing page as the first breadcrumb
      result = <<~HTML.strip
        <span class="breadcrumb-link"><a href="/guide/">Elastic Docs</a></span>
      HTML
      # Build an array of all levels...
      all = []
      parent = section
      while (parent = parent.parent)
        all << parent
      end
      # ... then reverse the array, go through each level,
      # build a link, and add it to the result
      result + all.reverse.map { |x| build_link(x, chev) }.join('')
    end

    def build_link(node, chev)
      extra = node.context == :document ? node.attr('title-extra') : ''
      link = <<~HTML.strip
        <span class="breadcrumb-link"><a #{link_href node}>#{node.title}#{extra}</a></span>
      HTML
      chev + link
    end
  end
end
