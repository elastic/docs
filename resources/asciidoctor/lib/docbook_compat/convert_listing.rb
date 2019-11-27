# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods code listings and their paired callout lists.
  module ConvertListing
    def convert_listing(node)
      lang = node.attr 'language'
      <<~HTML
        <div class="pre_wrapper lang-#{lang}">
        <pre class="programlisting prettyprint lang-#{lang}">#{node.content || ''}</pre>
        </div>
      HTML
    end

    def convert_inline_callout(node)
      %(<a id="#{node.id}"></a><i class="conum" data-value="#{node.text}"></i>)
    end

    def convert_colist(node)
      [
        '<div class="calloutlist">',
        '<table border="0" summary="Callout list">',
        node.items.map { |item| convert_colist_item item },
        '</table>',
        '</div>',
      ].flatten.compact.join "\n"
    end

    def convert_colist_item(item)
      [
        '<tr>',
        convert_colist_item_head(item),
        convert_colist_item_body(item),
        '</tr>',
      ]
    end

    def convert_colist_item_head(item)
      [
        '<td align="left" valign="top" width="5%">',
        "<p>#{convert_colist_item_coids item}</p>",
        '</td>',
      ]
    end

    def convert_colist_item_body(item)
      [
        '<td align="left" valign="top">',
        "<p>#{item.text}</p>",
        item.blocks? ? item.content : nil,
        '</td>',
      ]
    end

    def convert_colist_item_coids(item)
      return '' unless (coids = item.attr 'coids')

      result = []
      coids.split(' ').each do |coid|
        num = coid.split('-')[1]
        result << '<a href="#' << coid << '">'
        result << '<i class="conum" data-value="' << num << '"></i></a>'
      end
      result.join
    end
  end
end
