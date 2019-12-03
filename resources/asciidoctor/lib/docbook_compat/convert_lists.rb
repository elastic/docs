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

    def convert_dlist(node)
      [
        '<div class="variablelist">',
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        '<dl class="variablelist">',
        node.items.map { |terms, dd| convert_dlist_item terms, dd },
        '</dl>',
        '</div>',
      ].flatten.compact.join "\n"
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
      node.items.each do |item|
        next unless item.text
        next if item.blocks?

        html.sub!("<p>#{item.text}</p>", item.text) ||
          raise("Couldn't remove <p> for #{item.text} in #{html}")
      end
      html
    end

    def convert_dlist_item(terms, definition)
      [
        terms.map { |term| convert_dlist_term term },
        convert_dlist_definition(definition),
      ].flatten
    end

    def convert_dlist_term(term)
      [
        '<dt>',
        '<span class="term">',
        term.convert,
        '</span>',
        '</dt>',
      ]
    end

    def convert_dlist_definition(definition)
      return unless definition

      ['<dd>', definition.convert, '</dd>']
    end
  end
end
