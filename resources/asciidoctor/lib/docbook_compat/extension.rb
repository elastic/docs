# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'

##
# HTML5 converter that emulates Elastic's docbook generated html.
module DocbookCompat
  def self.activate(registry)
    return unless registry.document.basebackend? 'html'

    DelegatingConverter.setup(registry.document) { |d| Converter.new d }
  end

  ##
  # A Converter implementation that emulates Elastic's docbook generated html.
  class Converter < DelegatingConverter
    def initialize(delegate)
      super(delegate)
    end

    def convert_document(doc)
      html = yield
      html.gsub!(/<html lang="[^"]+">/, '<html>') ||
        raise("Coudn't fix html in #{html}")
      munge_head doc, html
      munge_body doc, html
      munge_title html
      html
    end

    def munge_head(doc, html)
      html.gsub!(%r{<title>(.+)</title>}, '<title>\1 | Elastic</title>') ||
        raise("Couldn't munge <title> in #{html}")
      munge_meta html
      add_dc_meta doc, html
    end

    META_VIEWPORT = <<~HTML
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    HTML
    def munge_meta(html)
      html.gsub!(
        %(<meta http-equiv="X-UA-Compatible" content="IE=edge">\n), ''
      ) || raise("Couldn't remove edge compat in #{html}")
      html.gsub!(META_VIEWPORT, '') ||
        raise("Couldn't remove viewport in #{html}")
      html.gsub!(/<meta name="generator" content="Asciidoctor [^"]+">\n/, '') ||
        raise("Couldn't remove generator in #{html}")
    end

    def add_dc_meta(doc, html)
      meta = <<~HTML.strip
        <meta name="DC.type" content="#{doc.attr 'dc.type'}"/>
        <meta name="DC.subject" content="#{doc.attr 'dc.subject'}"/>
        <meta name="DC.identifier" content="#{doc.attr 'dc.identifier'}"/>
      HTML
      html.gsub!('</title>', "</title>\n#{meta}") ||
        raise("Couldn't add dc meta to #{html}")
    end

    def munge_body(doc, html)
      wrapped_body = <<~HTML.strip
        <body>
        <div class="#{doc.doctype}" lang="#{doc.attr 'lang', 'en'}">
      HTML
      html.gsub!(/<body[^>]+>/, wrapped_body) ||
        raise("Couldn't wrap body in #{html}")
      html.gsub!('</body>', '</div></body>') ||
        raise("Couldn't wrap body in #{html}")
    end

    def munge_title(html)
      html.gsub!(/<div id="header">/, '<div class="titlepage"><div><div>') ||
        raise("Couldn't wrap header in #{html}")
      ided_title = <<~HTML.strip
        <h1 class="title">
        <a id="id-1"></a>
      HTML
      html.gsub!('<h1>', ided_title) || raise("Coudln't wrap h1 in #{html}")
      html.gsub!("</h1>\n</div>", "\n</h1>\n</div></div><hr></div>") ||
        raise("Couldn't wrap h1 in #{html}")
    end
  end
end
