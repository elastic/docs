# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert admonitions.
  module ConvertAdmonition
    def convert_admonition(node)
      [
        %(<div class="admon #{node.attr 'name'}">),
        %(<div class="admon-title">#{node.converter.convert(
          node,
          'admonition_title_id'
        )}</div>),
        node.converter.convert(
          node,
          'inner_content'
        ),
        '</div>',
      ].compact.join "\n"
    end

    def convert_inner_content(node)
      return if node.content == ''

      inner_content =
        if node.blocks.empty?
          "<p>#{node.content}</p>"
        else
          node.content
        end
      "<div class=\"admon_content\">\n#{inner_content}\n</div>"
    end

    def convert_admonition_title_id(node)
      return node.id ? %(<a id="#{node.id}"></a>) : nil unless node.title

      [
        node.title,
        node.id ? %(<a id="#{node.id}"></a>) : nil,
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
      name =
        if (node.attr 'name').to_s == 'experimental'
          'preview'
        else
          (node.attr 'name').to_s
        end
      message_title = node.attr 'message_title'
      [
        %(<span class="Admonishment Admonishment--#{name}">),
        %(<span class="#{title_classes}">#{node.attr 'title'}</span>),
        '<span class="Admonishment-detail">',
        %(<span class="version-details-title">#{message_title}</span>),
        node.text ? "<span class=\"version-details\">#{node.text}</span>" : nil,
        '</span>',
        '</span>',
      ].join "\n"
    end
  end
end
