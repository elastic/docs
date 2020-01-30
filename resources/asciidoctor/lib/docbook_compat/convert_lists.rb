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
      override_style = node.style.nil?
      # The style can be a symbol or the a string.....
      override_style ||= %w[arabic loweralpha].include? node.style.to_s
      node.style = 'orderedlist' if override_style
      convert_list node, &block
    end

    def convert_list_item(item)
      return item.text unless item.blocks?
      return item.content unless item.text

      [
        '<p>',
        item.text,
        '</p>',
        item.content,
      ].compact.join "\n"
    end

    private

    def convert_list(node)
      node.items.each { |item| item.attributes['role'] ||= 'listitem' }
      html = yield
      html.sub!(
        %r{<div class="title">#{node.title}</div>},
        %(<p class="title"><strong>#{node.title}</strong></p>)
      )
      munge_list_items node, html
      html
    end

    def munge_list_items(node, html)
      node.items.each do |item|
        next unless item.text
        next if item.blocks?

        text = item_text node, item
        html.sub!("<p>#{text}</p>", text) ||
          raise("Couldn't remove <p> for #{text} in #{html}")
      end
    end

    def item_text(node, item)
      if item.attr? 'checked'
        checked_text(node) + item.text
      elsif item.attr? 'checkbox'
        checkbox_text(node) + item.text
      else
        item.text
      end
    end

    def checked_text(node)
      if node.option? 'interactive'
        '<input type="checkbox" data-item-complete="1" checked> '
      else
        '&#10003; '
      end
    end

    def checkbox_text(node)
      if node.option? 'interactive'
        '<input type="checkbox" data-item-complete="0"> '
      else
        '&#10063; '
      end
    end
  end
end
