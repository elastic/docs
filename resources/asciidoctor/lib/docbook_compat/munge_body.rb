# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to munge the generated html around the `<body>` tags.
  module MungeBody
    def munge_body(doc, html)
      if doc.attr 'noheader'
        html.gsub!(/<body[^>]+>/, "<body>#{extra_page_header doc}")
      else
        munge_body_and_header_open doc, html
        munge_body_and_header_close html
      end
    end

    def munge_body_and_header_open(doc, html)
      # Note nav header and footer should be *outside* the div wrapping the body
      wrapped = [
        %(<body>),
        extra_page_header(doc),
        html.slice!(%r{<div class="navheader">.+?<\/div>\n}m)&.strip,
        %(<div class="#{doc.doctype}" lang="#{doc.attr 'lang', 'en'}">),
      ].compact.join "\n"
      html.gsub!(/<body[^>]+>/, wrapped) ||
        raise("Couldn't wrap body in #{html}")
    end

    def extra_page_header(doc)
      return unless (extra = doc.attr 'page-header')

      <<~HTML.strip
        <div class="page_header">
        #{extra}
        </div>
      HTML
    end

    def munge_body_and_header_close(html)
      wrapped = [
        '</div>',
        html.slice!(%r{<div class="navfooter">.+?<\/div>\n}m),
        '</body>',
      ].compact.join
      html.gsub!('</body>', wrapped) ||
        raise("Couldn't wrap body in #{html}")
    end
  end
end
