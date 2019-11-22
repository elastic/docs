# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert lists.
  module ConvertLists
    def convert_ulist(node)
      node.style ||= 'itemizedlist'
      node.items.each { |item| item.attributes['role'] ||= 'listitem' }
      html = yield
      node.items.each do |item|
        next unless item.text

        html.sub!("<p>#{item.text}</p>", item.text) ||
          raise("Couldn't remove <p> for #{item.text} in #{html}")
      end
      html
    end
  end
end
