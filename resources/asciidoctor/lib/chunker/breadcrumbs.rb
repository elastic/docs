# frozen_string_literal: true

require_relative 'link'

module Chunker
  ##
  # Builds the "breadcrumbs" at the top of the page.
  module Breadcrumbs
    include Link

    def generate_breadcrumbs(doc, section)
      chev = <<~HTML.strip
        <span class="chevron-right">›</span>
      HTML
      result = ['<div class="breadcrumbs">']
      result += generate_breadcrumb_links(section, chev).reverse
      result << '</div>'

      if result[2].to_s.include? 'APM'
        result[2] = chev + generate_apm_breadcrumbs(doc)
      end
      if result[2].to_s.include? 'ECS Logging'
        result[2] = chev + generate_ecslogging_breadcrumbs(doc)
      end
      if result[2].to_s.include? 'Enterprise Search'
        result[2] = chev + generate_search_breadcrumbs(doc, 'Enterprise Search')
      end
      if result[2].to_s.include? 'App Search'
        result[2] = chev + generate_search_breadcrumbs(doc, 'App Search')
      end
      if result[2].to_s.include? 'Workplace Search'
        result[2] = chev + generate_search_breadcrumbs(doc, 'Workplace Search')
      end
      Asciidoctor::Block.new doc, :pass, source: result.join("\n")
    end

    def generate_apm_breadcrumbs(doc)
      title = doc.title
      short = title.sub(/APM /, '')
      <<~HTML.strip
        <span class="breadcrumb-link">
          <div id="related-products" class="dropdown">
            <div class="related-products-title">APM:</div>
            <div class="dropdown-anchor" tabindex="0">#{short}<span class="dropdown-icon"></span></div>
            <div class="dropdown-content">
              <ul>
                <li class="dropdown-category">APM</li>
                <ul>
                  <li><a href="/guide/en/apm/guide/current/apm-overview.html">User Guide</a></li>
                </ul>
                <li class="dropdown-category">APM agents</li>
                <ul>
                  <li><a href="/guide/en/apm/agent/android/current/intro.html">Android Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/go/current/introduction.html">Go Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/swift/current/intro.html">iOS Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/java/current/intro.html">Java Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/dotnet/current/intro.html">.NET Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/nodejs/current/intro.html">Node.js Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/php/current/intro.html">PHP Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/python/current/getting-started.html">Python Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/ruby/current/introduction.html">Ruby Agent Reference</a></li>
                  <li><a href="/guide/en/apm/agent/rum-js/current/intro.html">Real User Monitoring JavaScript Agent Reference</a></li>
                </ul>
                <li class="dropdown-category">APM extensions</li>
                <ul>
                  <li><a href="/guide/en/apm/lambda/current/aws-lambda-arch.html">Monitoring AWS Lambda Functions</a></li>
                  <li><a href="/guide/en/apm/attacher/current/apm-attacher.html">Attacher</a></li>
                </ul>
              </ul>
            </div>
          </div>
        </span>
      HTML
    end

    def generate_ecslogging_breadcrumbs(doc)
      title = doc.title
      short = title.sub(/ECS Logging /, '')
      <<~HTML.strip
        <span class="breadcrumb-link">
          <div id="related-products" class="dropdown">
            <div class="related-products-title">ECS Logging:</div>
            <div class="dropdown-anchor" tabindex="0">#{short}<span class="dropdown-icon"></span></div>
            <div class="dropdown-content">
              <ul>
                <li><a href="/guide/en/ecs-logging/overview/current/intro.html">Reference</a></li>
                <li><a href="/guide/en/ecs-logging/go-logrus/current/intro.html">Go (Logrus) Reference</a></li>
                <li><a href="/guide/en/ecs-logging/go-zap/current/intro.html">Go (zap) Reference</a></li>
                <li><a href="/guide/en/ecs-logging/java/current/intro.html">Java Reference</a></li>
                <li><a href="/guide/en/ecs-logging/dotnet/current/intro.html">.NET Reference</a></li>
                <li><a href="/guide/en/ecs-logging/nodejs/current/intro.html">Node.js Reference</a></li>
                <li><a href="/guide/en/ecs-logging/ruby/current/intro.html">Ruby Reference</a></li>
                <li><a href="/guide/en/ecs-logging/php/current/intro.html">PHP Reference</a></li>
                <li><a href="/guide/en/ecs-logging/python/current/intro.html">Python Reference</a></li>
            </div>
          </div>
        </span>
      HTML
    end

    def generate_search_breadcrumbs(doc, search_type)
      title = doc.title
      short = title.sub(/ documentation/, '')
      books = {
        'Enterprise Search' => '/guide/en/enterprise-search/current/index.html',
        'App Search' => '/guide/en/app-search/current/index.html',
        'Workplace Search' => '/guide/en/workplace-search/current/index.html'
      }
      clients = {
        'Node.js client' => 'https://www.elastic.co/guide/en/enterprise-search-clients/enterprise-search-node/current/index.html',
        'PHP client' => 'https://www.elastic.co/guide/en/enterprise-search-clients/php/current/index.html',
        'Python client' => 'https://www.elastic.co/guide/en/enterprise-search-clients/python/current/index.html',
        'Ruby client' => 'https://www.elastic.co/guide/en/enterprise-search-clients/ruby/current/index.html'
      }
      <<~HTML.strip
        <span class="breadcrumb-link">
          <div id="related-products" class="dropdown">
            <div class="related-products-title"></div>
            <div class="dropdown-anchor" tabindex="0">#{short}<span class="dropdown-icon"></span></div>
            <div class="dropdown-content">
              <ul>
                <li class="dropdown-category">Enterprise Search guides</li>
                <ul>
                  #{books.map { |name, link| "<li><a href=\"#{link}\" target=\"_blank\">#{name}</a></li>" }.join("\n")}
                </ul>
                <li class="dropdown-category">Programming language clients</li>
                <ul>
                  #{clients.map { |name, link| "<li><a href=\"#{link}\" target=\"_blank\">#{name}</a></li>" }.join("\n")}
                </ul>
              </ul>
            </div>
          </div>
        </span>
      HTML
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
