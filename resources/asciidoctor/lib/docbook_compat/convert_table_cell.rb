# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert tables.
  module ConvertTableCell
    def convert_table_cell(cell, data_tag, wrap_text)
      result = [convert_cell_open(cell, data_tag)]
      if cell.inner_document
        result << "\n" << cell.content << "\n"
      else
        result << '<p>' if wrap_text
        result << cell.text
        result << '</p>' if wrap_text
      end
      result << '</' << data_tag << '>'
      result.join
    end

    def convert_cell_open(cell, data_tag)
      [
        '<',
        data_tag,
        ' ',
        cell_open_attrs(cell).map { |k, v| %(#{k}="#{v}") }.join(' '),
        '>',
      ].join
    end

    def cell_open_attrs(cell)
      {
        align: 'left',
        colspan: cell.colspan == 1 ? nil : cell.colspan,
        rowspan: cell.rowspan == 1 ? nil : cell.rowspan,
        valign: 'top',
      }.compact
    end
  end
end
