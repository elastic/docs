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
      munge_head doc.attr('title-extra'), html
      munge_body doc, html
      munge_title doc, title, html
      add_toc doc, html if wants_toc
    end

    def munge_html_tag(html)
      html.gsub!(/<html lang="[^"]+">/, '<html>') ||
        raise("Coudn't fix html in #{html}")
    end

    def munge_head(title_extra, html)
      if html !~ %r{^<title>([\S\s]+)<\/title>$}m
        raise("Couldn't munge <title> in #{html}")
      end

      html.gsub!(%r{^<title>([\S\s]+)<\/title>$}m) do
        add_content_meta Regexp.last_match[1], title_extra
      end
      munge_meta html
    end

    def add_content_meta(match, title_extra)
      # If multiple lines, get just the first line
      clean_title = match.gsub!(/\n[\S\s]+/, '') || match
      clean_title = strip_tags clean_title
      <<~HTML
        <title>#{clean_title}#{title_extra} | Elastic</title>
        <meta class=\"elastic\" name=\"content\" \
        content=\"#{clean_title}#{title_extra}\">
      HTML
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
      # Important: we're not replacing the whole header - it still will have a
      # closing </div>.
      #
      # We also add a placeholder for the breadcrumbs that will be replaced
      # in resources/asciidoctor/lib/chunker/extension.rb
      header_start = <<~HTML
        <div class="titlepage">
        <div id="breadcrumbs-go-here"></div>
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
