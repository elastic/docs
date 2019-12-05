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
      xref = %(<a class="xref" href="#{node.target}")
      refid = node.attributes['refid']
      ref = node.document.catalog[:refs][refid]
      return "#{xref}>#{refid}</a>" unless ref

      text = node.text || ref_text_for(ref, node)
      title = ref.respond_to?(:title) ? ref.title : nil
      <<~HTML.strip
        #{xref}#{title ? %(title="#{title}") : ''}>#{text}</a>
      HTML
    end

    def ref_text_for(ref, node)
      if ref.node_name == 'inline_link'
        special = ref_text_for_inline_link ref
        return special if special
      end

      ref.xreftext node.attr('xrefstyle', 'short', true)
    end

    ##
    # Inline title's have *boring* text so we instead use the text of the
    # next element. This is also what docbook does. Because it is better.
    def ref_text_for_inline_link(ref)
      return unless (parent = ref.parent)
      return unless (index = parent.blocks.find_index ref)

      parent[index + 1]&.convert
    end
  end
end
