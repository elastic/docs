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
      text = ref.xreftext node.attr('xrefstyle', 'short', true)
      return text if text

      # The text is empty! Let's grab the parent section's heading.
      section = ref.parent
      section = section.parent until section.context == :section

      # Docbook doesn't use 'short' as the default here, strangely. So neither
      # do we.
      section.xreftext nil
    end
  end
end
