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
      extra_classes = node.roles.empty? ? '' : " #{node.roles.join ' '}"
      [
        %(<div class="calloutlist#{extra_classes}">),
        '<table border="0" summary="Callout list">',
        node.items.each_with_index.map do |item, index|
          convert_colist_item item, index
        end,
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
        convert_listing_body_with_language node, lang
      else
        %(<pre class="screen">#{node.content || ''}</pre>)
      end
    end

    def convert_listing_body_with_language(node, lang)
      extra_classes = node.roles.empty? ? '' : " #{node.roles.join ' '}"
      pre_classes = "programlisting prettyprint lang-#{lang}#{extra_classes}"
      [
        %(<div class="pre_wrapper lang-#{lang}#{extra_classes}">),
        %(<pre class="#{pre_classes}">#{node.content || ''}</pre>),
        %(</div>),
      ].join "\n"
    end

    def convert_colist_item(item, index)
      [
        '<tr>',
        convert_colist_item_head(item, index),
        convert_colist_item_body(item),
        '</tr>',
      ]
    end

    def convert_colist_item_head(item, index)
      [
        '<td align="left" valign="top" width="24px">',
        "<p>#{convert_colist_item_coids item, index}</p>",
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

    def convert_colist_item_coids(item, index)
      return '' unless (coids = item.attr 'coids')

      coids = coids.split(' ')
      return '' unless (first = coids.shift)

      [
        %(<a href="##{first}">),
        %(<i class="conum" data-value="#{index + 1}"></i></a>),
        coids.map { |coid| %(<a href="##{coid}"></a>) },
      ].compact.join
    end
  end
end
