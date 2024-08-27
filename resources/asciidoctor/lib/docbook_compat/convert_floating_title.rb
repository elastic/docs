# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert floating titles.
  module ConvertFloatingTitle
    def convert_floating_title(node)
      tag_name = %(h#{node.level + 1})
      [
        '<div class="position-relative">',
        '<', tag_name, node.role ? %( class="#{node.role}") : nil, '>',
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        node.title,
        xpack_tag(node),
        '</', tag_name, '>',
        node.attr('edit_me_link', ''),
        '</div>'
      ].compact.join
    end
  end
end
