# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert floating titles.
  module ConvertFloatingTitle
    def convert_floating_title(node)
      tag_name = %(h#{node.level + 1})
      [
        '<', tag_name, '>',
        node.role ? %( class="#{node.role}") : nil,
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        node.title,
        node.attr('edit_me_link', ''),
        xpack_tag(node),
        '</', tag_name, '>'
      ].compact.join
    end
  end
end
