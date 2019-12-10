# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert table cells.
  module ConvertTableCell
    def convert_table_cell(cell, data_tag, allow_formatting)
      result = [convert_cell_open(cell, data_tag)]
      result += convert_cell_content(cell, allow_formatting)
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
        ["\n", cell.content, "\n"]
      elsif allow_formatting
        ['<p>', cell_text(cell), '</p>']
      else
        [cell.text]
      end
    end

    def cell_text(cell)
      return cell.text unless (style = cell.attr 'style')

      cell.document.converter.convert cell, "cell_text_#{style}"
    rescue NoMethodError
      warn block: cell, message: "Unknown style for cell [#{style}]."
      convert_cell_text_none cell
    end

    def convert_cell_text_emphasis(cell)
      delegate_cell_text cell, :emphasis
    end

    def convert_cell_text_header(cell)
      convert_cell_text_strong cell
    end

    def convert_cell_text_literal(cell)
      delegate_cell_text cell, :literal
    end

    def convert_cell_text_monospaced(cell)
      delegate_cell_text cell, :monospaced
    end

    def convert_cell_text_none(cell)
      cell.text
    end

    def convert_cell_text_strong(cell)
      delegate_cell_text cell, :strong
    end

    def convert_cell_text_verse(cell)
      delegate_cell_text cell, :verse
    end

    private

    def delegate_cell_text(cell, type)
      Asciidoctor::Inline.new(
        cell.parent, :quoted, cell.text, type: type
      ).convert
    end
  end
end
