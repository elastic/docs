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
      if result[2].to_s.include? 'APM'
        result[2] = generate_apm_breadcrumbs(doc)
      end
      if result[2].to_s.include? 'ECS Logging'
        result.insert(2, generate_ecslogging_breadcrumbs)
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
            <div class="dropdown-anchor">#{short}<span class="dropdown-icon"></span></div>
            <div class="dropdown-content">
              <ul>
                <li class="dropdown-category">APM</li>
                <ul>
                  <li><a id="guide" href="http://localhost:8000/guide/index.html">User Guide</a></li>
                </ul>
                <li class="dropdown-category">APM agents</li>
                <ul>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/android/current/index.html">Android Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/go/current/index.html">Go Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/swift/current/index.html">iOS Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/java/current/index.html">Java Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/dotnet/current/index.html">.NET Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/nodejs/current/index.html">Node.js Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/php/current/index.html">PHP Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/python/current/index.html">Python Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/ruby/current/index.html">Ruby Agent Reference</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/agent/rum-js/current/index.html">Real User Monitoring JavaScript Agent Reference</a></li>
                </ul>
                <li class="dropdown-category">APM extensions</li>
                <ul>
                  <li><a href="https://www.elastic.co/guide/en/apm/lambda/current/index.html">Monitoring AWS Lambda Functions</a></li>
                  <li><a href="https://www.elastic.co/guide/en/apm/attacher/current/index.html">Attacher</a></li>
                </ul>
              </ul>
          </div>
        </div>
        <span class="chevron-right">›</span>
      HTML
    end

    def generate_ecslogging_breadcrumbs
      <<~HTML.strip
        <span class="breadcrumb-link">
          <div class="dropdown">
            <span>ECS Logging ▾</span>
              <div class="dropdown-content">
                <strong>ECS Logging</strong></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/overview/current/index.html">Overview</a></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/go-logrus/current/index.html">Go (Logrus)</a></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/go-zap/current/index.html">Go (Zap)</a></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/java/current/index.html">Java</a></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/dotnet/current/index.html">.NET</a></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/nodejs/current/index.html">Node.js</a></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/ruby/current/index.html">Ruby</a></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/php/current/index.html">PHP</a></br>
                <a href="https://www.elastic.co/guide/en/ecs-logging/python/current/index.html">Python</a></br>
            </div>
          </div>
        <span class="chevron-right">›</span>
      HTML
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
        <span class="breadcrumb-link"><a href="/guide/">Elastic Docs</a></span><span class="chevron-right">›</span>
      HTML
      result
    end
  end
end
