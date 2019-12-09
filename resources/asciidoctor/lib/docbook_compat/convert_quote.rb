# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert tables.
  module ConvertQuote
    def convert_quote(node)
      return convert_fancy_quote node if node.attr 'attribution'

      yield
    end

    def convert_fancy_quote(node)
      [
        '<div class="blockquote">',
        '<table border="0" class="blockquote" summary="Block quote">',
        convert_quote_row(node),
        convert_attribution_row(node),
        '</table>',
        '</div>',
      ].compact.join "\n"
    end

    private

    def convert_quote_row(node)
      [
        '<tr>',
        '<td valign="top" width="10%"></td>',
        '<td valign="top" width="80%">',
        node.content,
        '</td>',
        '<td valign="top" width="10%"></td>',
        '</tr>',
      ]
    end

    def convert_attribution_row(node)
      [
        '<tr>',
        '<td valign="top" width="10%"></td>',
        '<td align="right" colspan="2" valign="top">',
        %(-- <span class="attribution">#{node.attr 'attribution'}</span>),
        '</td>',
        '</tr>',
      ]
    end
  end
end
