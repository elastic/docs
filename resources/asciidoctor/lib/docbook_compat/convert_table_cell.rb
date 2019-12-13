# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert table cells.
  module ConvertTableCell
    def convert_table_cell(cell, data_tag, allow_formatting)
      result = [convert_cell_open(cell, data_tag)]
      result << convert_cell_content(cell, allow_formatting)
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
        align: cell.attr('halign'),
        colspan: cell.colspan == 1 ? nil : cell.colspan,
        rowspan: cell.rowspan == 1 ? nil : cell.rowspan,
        valign: cell.attr('valign'),
      }.compact
    end

    def convert_cell_content(cell, allow_formatting)
      if cell.inner_document
        ["\n", cell.content, "\n"].join
      elsif allow_formatting
        cell_text cell
      else
        cell.text
      end
    end

    def cell_text(cell)
      cell.style = :strong if cell.style == :header
      "<p>#{cell.content.join "</p>\n<p>"}</p>"
    end
  end
end
