# frozen_string_literal: true

##
# Strips tags from html.
module StripTags
  def strip_tags(html)
    return unless html

    html.gsub(/<[^>]*>/, '').squeeze(' ').strip
  end
end
