# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert lists.
  module ConvertSidebar
    def convert_sidebar(node)
      [
        %(<div class="sidebar#{node.role ? " #{node.role}" : ''}">),
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        node.document.converter.convert(node, 'sidebar_title'),
        node.content,
        '</div>',
      ].compact.join "\n"
    end

    def convert_sidebar_title(node)
      return '<div class="titlepage"></div>' unless node.title

      [
        '<div class="titlepage"><div><div>',
        %(<p class="title"><strong>#{node.title}</strong></p>),
        %(</div></div></div>),
      ].join "\n"
    end
  end
end
