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
      return false unless (parent = node.parent)
      return false if parent.id

      case parent.context
      when :section
        # the first level 0 heading doesn't ever auto-generate an id so we
        # need to render the docs.
        parent.level != 0 || parent.index != 0
      when :floating_title
        true
      else
        false
      end
    end

    def convert_inline_admonition_for_real(node)
      title_classes =
        "Admonishment-#{node.attr 'title_type'} #{node.attr 'title_class'}"
      [
        %(<span class="Admonishment Admonishment--#{node.type}">),
        %(<span class="#{title_classes}">#{node.attr 'title'}</span>),
        '<span class="Admonishment-detail">',
        node.text,
        '</span>',
        '</span>',
      ].join "\n"
    end
  end
end
