# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert lists.
  module ConvertLists
    def convert_ulist(node, &block)
      node.style ||= 'itemizedlist'
      convert_list node, &block
    end

    def convert_olist(node, &block)
      node.style = 'orderedlist' if node.style.nil? || node.style == 'arabic'
      convert_list node, &block
    end

    def convert_list(node)
      node.items.each { |item| item.attributes['role'] ||= 'listitem' }
      html = yield
      node.items.each do |item|
        next unless item.text
        next if item.blocks?

        html.sub!("<p>#{item.text}</p>", item.text) ||
          raise("Couldn't remove <p> for #{item.text} in #{html}")
      end
      html
    end
  end
end
