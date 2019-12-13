# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert "inline quoted" which is mostly markup.
  module ConvertInlineQuoted
    def convert_inline_quoted(node, &block)
      [
        convert_inline_quoted_main(node, &block),
        xpack_tag(node),
      ].compact.join
    end

    private

    def convert_inline_quoted_main(node)
      case node.type
      when :monospaced
        node.attributes['role'] ||= 'literal'
        yield
      when :strong
        # Docbook's "strong" rendering is comically repetitive.....
        %(<span class="strong strong"><strong>#{node.text}</strong></span>)
      else
        yield
      end
    end
  end
end
