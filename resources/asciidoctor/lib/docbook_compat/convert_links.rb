# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert links.
  module ConvertLinks
    def convert_inline_anchor(node)
      case node.type
      when :link
        node.attributes['role'] = 'ulink'
        node.attributes['window'] ||= '_top'
        yield
      when :xref
        convert_xref node
      else
        yield
      end
    end

    def convert_xref(node)
      refid = node.attributes['refid']
      if (ref = node.document.catalog[:refs][refid])
        title = ref.title
        text = ref.xreftext node.attr('xrefstyle', 'short', true)
        %(<a class="xref" href="#{node.target}" title="#{title}">#{text}</a>)
      else
        %(<a class="xref" href="#{node.target}">#{refid}</a>)
      end
    end
  end
end
