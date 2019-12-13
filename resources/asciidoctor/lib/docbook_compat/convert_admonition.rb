# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert admonitions.
  module ConvertAdmonition
    def convert_admonition(node)
      [
        %(<div class="#{node.attr 'name'} admon">),
        %(<div class="icon"></div>),
        %(<div class="admon_content">),
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        node.title? ? "<h3>#{node.title}</h3>" : nil,
        node.blocks.empty? ? "<p>#{node.content}</p>" : node.content,
        '</div>',
        '</div>',
      ].compact.join "\n"
    end

    def convert_inline_admonition(node)
      title_classes =
        "Admonishment-#{node.attr 'title_type'} #{node.attr 'title_class'}"
      [
        %(<span class="Admonishment Admonishment--#{node.type}">),
        %([<span class="#{title_classes}">#{node.attr 'title'}</span>]),
        '<span class="Admonishment-detail">',
        node.text,
        '</span>',
        '</span>',
      ].join "\n"
    end
  end
end
