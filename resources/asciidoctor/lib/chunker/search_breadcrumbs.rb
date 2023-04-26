# frozen_string_literal: true
module Chunker
##
# methods for generating breadcrumbs for Enterprise Search book
  module Search_breadcrumbs
    def generate_search_breadcrumbs(doc, _search_type)
        title = doc.title
        short = title.sub(/ documentation/, '')
        books = {
          'Enterprise Search' => '/guide/en/enterprise-search/current/index.html',
          'App Search' => '/guide/en/app-search/current/index.html',
          'Workplace Search' => '/guide/en/workplace-search/current/index.html',
        }
        clients = {
          'Node.js client' => 'https://www.elastic.co/guide/en/enterprise-search-clients/enterprise-search-node/current/index.html',
          'PHP client' => 'https://www.elastic.co/guide/en/enterprise-search-clients/php/current/index.html',
          'Python client' => 'https://www.elastic.co/guide/en/enterprise-search-clients/python/current/index.html',
          'Ruby client' => 'https://www.elastic.co/guide/en/enterprise-search-clients/ruby/current/index.html',
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
    end
    end
