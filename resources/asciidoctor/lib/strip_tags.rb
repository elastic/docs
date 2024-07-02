# frozen_string_literal: true

##
# Strips tags from html.
module StripTags
  def strip_tags(html)
    return unless html

    # Remove inline admonitions. This is kind of a lame way to do it but
    # Asciidoctor doesn't give us a better way.
    html = html.gsub(%r{
      <span\ class="Admonishment.+
      <span\ class.+</span>.+
      <span\ class=".+
      </span>\n
      </span>
    }xm, '')
    # Comment to fix up syntax highlighting "HTML
    html.gsub(/<[^>]*>/, '').squeeze(' ').strip
  end
end
