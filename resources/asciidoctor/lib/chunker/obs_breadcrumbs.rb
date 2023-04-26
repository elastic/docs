# frozen_string_literal: true

module Chunker
    ##
    # methods for generating breadcrumbs for Obs docs books
  module Obs_Breadcrumbs
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
                </ul>
              </div>
            </div>
          </span>
        HTML
    end
end
end
