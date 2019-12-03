# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert lists.
  module ConvertDList
    def convert_dlist(node)
      style = node.style || 'vertical'
      node.converter.convert node, "#{style}_dlist"
    end

    def convert_vertical_dlist(node)
      [
        '<div class="variablelist">',
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        '<dl class="variablelist">',
        node.items.map { |terms, dd| convert_vertical_dlist_item terms, dd },
        '</dl>',
        '</div>',
      ].flatten.compact.join "\n"
    end

    HORIZONTAL_DLIST_INTRO = [
      '<div class="informaltable">',
      '<table border="0" cellpadding="4px">',
      '<colgroup>',
      '<col/>',
      '<col/>',
      '</colgroup>',
      '<tbody valign="top">',
    ].freeze
    HORIZONTAL_DLIST_OUTRO = [
      '</tbody>',
      '</table>',
      '</div>',
    ].freeze
    def convert_horizontal_dlist(node)
      [
        HORIZONTAL_DLIST_INTRO,
        node.items.map { |terms, dd| convert_horizontal_dlist_item terms, dd },
        HORIZONTAL_DLIST_OUTRO,
      ].flatten
    end

    private

    def convert_vertical_dlist_item(terms, definition)
      [
        terms.map { |term| convert_vertical_dlist_term term },
        convert_vertical_dlist_definition(definition),
      ].flatten
    end

    def convert_vertical_dlist_term(term)
      [
        '<dt>',
        '<span class="term">',
        term.convert,
        '</span>',
        '</dt>',
      ]
    end

    def convert_vertical_dlist_definition(definition)
      return unless definition

      ['<dd>', definition.convert, '</dd>']
    end

    def convert_horizontal_dlist_item(terms, definition)
      [
        '<tr>',
        '<td valign="top">',
        terms.map { |term| convert_horizontal_dlist_term term },
        '</td>',
        convert_horizontal_dlist_definition(definition),
        '</tr>',
      ].flatten
    end

    def convert_horizontal_dlist_term(term)
      ['<p>', term.convert, '</p>']
    end

    def convert_horizontal_dlist_definition(definition)
      ['<td valign="top">', '<p>', definition&.convert, '</p>', '</td>'].compact
    end
  end
end
