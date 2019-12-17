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
        node.converter.convert(node, 'admonition_title_id'),
        node.blocks.empty? ? "<p>#{node.content}</p>" : node.content,
        '</div>',
        '</div>',
      ].compact.join "\n"
    end

    def convert_admonition_title_id(node)
      return node.id ? %(<a id="#{node.id}"></a>) : nil unless node.title

      [
        '<h3>',
        node.title,
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        '</h3>',
      ].compact.join
    end

    def convert_inline_admonition(node)
      return '' if skip_inline_admonition node

      convert_inline_admonition_for_real node
    end

    ##
    # If the parent is a section and it doesn't yet have an id then we're
    # being invoked during the parse phase to generate an id for that section.
    # We don't want to include the admonition in the id so we convert as
    # empty string. ClearCachedTitles will make sure we get reconverted
    # when we're rendered.
    def skip_inline_admonition(node)
      return false unless node.parent
      return false if node.parent.id

      %i[section floating_title].include? node.parent.context
    end

    def convert_inline_admonition_for_real(node)
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
