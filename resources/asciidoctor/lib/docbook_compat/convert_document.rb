# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert the document at the top level. All of these are a bit
  # scary but required at this point for docbook compatibility.
  module ConvertDocument
    def convert_document(doc)
      # We'll manually add the toc ourselves if it was requested.
      wants_toc = doc.attr?('toc') && doc.attr?('toc-placement', 'auto')
      doc.attributes.delete 'toc' if wants_toc

      html = yield
      html.gsub!(/<html lang="[^"]+">/, '<html>') ||
        raise("Coudn't fix html in #{html}")
      munge_head doc, html
      munge_body doc, html
      munge_title doc, html
      add_toc doc, html if wants_toc
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

    def munge_title(doc, html)
      id = doc.id || 'id-1'
      # Important: we're not replacing he whole header - it still will have a
      # closing </div>.
      header_start = <<~HTML
        <div class="titlepage">
        <div><div>
        <h1 class="title"><a id="#{id}"></a>#{doc.title}</h1>
        </div></div>
        <hr>
      HTML
      html.gsub!(%r{<div id="header">\n<h1>.+</h1>\n}, header_start) ||
        raise("Couldn't wrap header in #{html}")
    end

    def add_toc(doc, html)
      html.gsub! '<div id="content">', <<~HTML
        <div id="content">
        <div class="#{doc.attr 'toc-class', 'toc'}">
        #{convert doc, 'outline'}
        </div>
      HTML
    end
  end
end
