# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods code listings and their paired callout lists.
  module ConvertListing
    def convert_listing(node)
      [
        node.title ? '<p>' : nil,
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        node.title ? convert_listing_title(node) : nil,
        convert_listing_body(node),
      ].compact.join
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

    private

    def convert_listing_title(node)
      title = '<strong>' + node.title
      title += '.' unless [':', '.'].include? node.title[-1]
      title += "</strong></p>\n"
      title
    end

    def convert_listing_body(node)
      if (lang = node.attr 'language')
        pre_classes = "programlisting prettyprint lang-#{lang}"
        [
          %(<div class="pre_wrapper lang-#{lang}">),
          %(<pre class="#{pre_classes}">#{node.content || ''}</pre>),
          %(</div>),
        ].join "\n"
      else
        %(<pre class="screen">#{node.content || ''}</pre>)
      end
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
