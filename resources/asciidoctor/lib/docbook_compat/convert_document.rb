# frozen_string_literal: true

require_relative 'extra_docinfo'
require_relative 'munge_body'

module DocbookCompat
  ##
  # Methods to convert the document at the top level. All of these are a bit
  # scary but required at this point for docbook compatibility.
  module ConvertDocument
    include MungeBody

    def convert_document(doc)
      # We'll manually add the toc ourselves if it was requested.
      wants_toc = doc.attr?('toc') && doc.attr?('toc-placement', 'auto')
      doc.attributes.delete 'toc' if wants_toc

      doc.extend ExtraDocinfo

      html = yield
      munge_html doc, html, wants_toc
      html + "\n"
    end

    def munge_html(doc, html, wants_toc)
      title = doc.doctitle partition: true
      munge_html_tag html
      munge_head doc.attr('title-extra'), title, html
      munge_body doc, html
      munge_title doc, title, html
      add_toc doc, html if wants_toc
    end

    def munge_html_tag(html)
      html.gsub!(/<html lang="[^"]+">/, '<html>') ||
        raise("Coudn't fix html in #{html}")
    end

    def munge_head(title_extra, title, html)
      html.gsub!(
        %r{<title>.+?</title>}m, <<~HTML
          <title>#{strip_tags title.main}#{title_extra} | Elastic</title>
          <meta class=\"elastic\" name=\"content\" \
          content=\"#{strip_tags title.main}#{title_extra}\">
        HTML
      ) || raise("Couldn't munge <title> in #{html}")
      munge_meta html
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

    def munge_title(doc, title, html)
      return if doc.attr 'noheader'

      # Important: we're not replacing the whole header - it still will have a
      # closing </div>.
      header_start = <<~HTML
        <div class="titlepage">
        <div class="breadcrumbs" id="title-page-breadcrumb">
        <span class="breadcrumb-link"><a href="/guide/">Elastic Docs</a></span>
        </div>
        #{docbook_style_title doc, title}
      HTML
      html.gsub!(%r{<div id="header">\n<h1>.+?</h1>\n}m, header_start) ||
        raise("Couldn't wrap header in #{html}")
    end

    def docbook_style_title(doc, title)
      id = doc.id || 'id-1'
      result = <<~HTML
        <div>
        <div><h1 class="title"><a id="#{id}"></a>#{title.main}</h1></div>
      HTML
      result += <<~HTML if title.subtitle?
        <div><h2 class="subtitle">#{title.subtitle}</h2></div>
      HTML
      result + <<~HTML.strip
        </div>
        <!--EXTRA-->
      HTML
    end

    def add_toc(doc, html)
      html.gsub! '<div id="content">', <<~HTML
        <div id="content">
        <!--START_TOC-->
        <div class="#{doc.attr 'toc-class', 'toc'}">
        #{doc.converter.convert doc, 'outline'}
        </div>
        <!--END_TOC-->
      HTML
    end
  end
end
