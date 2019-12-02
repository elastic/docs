# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert tables.
  module ConvertTable
    def convert_table(node)
      [
        '<div class="informaltable">',
        '<table border="1" cellpadding="4px">',
        convert_colgroups(node),
        convert_parts(node),
        '</table>',
        '</div>',
      ].flatten.join "\n"
    end

    private

    def convert_colgroups(node)
      [
        '<colgroup>',
        node.columns.map { |column| convert_colgroup column },
        '</colgroup>',
      ].flatten
    end

    def convert_colgroup(column)
      %(<col class="col_#{column.attr 'colnumber'}"/>)
    end

    def convert_parts(node)
      head, body, foot = pull_parts node
      result = []
      result += convert_head head unless head.empty?
      result += convert_body body unless body.empty?
      result += convert_foot foot unless foot.empty?
      result
    end

    def pull_parts(node)
      ((_head, head), (_body, body), (_foot, foot)) = node.rows.by_section
      [head, body, foot]
    end

    def convert_head(rows)
      [
        '<thead>',
        rows.map { |row| convert_row row, 'th', false },
        '</thead>',
      ].flatten
    end

    def convert_body(rows)
      [
        '<tbody>',
        rows.map { |row| convert_row row, 'td', true },
        '</tbody>',
      ].flatten
    end

    def convert_foot(rows)
      [
        '<tfoot>',
        rows.map { |row| convert_row row, 'td', false },
        '</tfoot>',
      ].flatten
    end

    def convert_row(row, data_tag, wrap_bare_data)
      [
        '<tr>',
        row.map { |cell| convert_cell cell, data_tag, wrap_bare_data },
        '</tr>',
      ].flatten
    end

    def convert_cell(cell, data_tag, wrap_bare_data)
      result = ['<', data_tag, ' align="left" valign="top">']
      if cell.inner_document
        result << "\n" << cell.content << "\n"
      else
        result << '<p>' if wrap_bare_data
        result << cell.text
        result << '</p>' if wrap_bare_data
      end
      result << '</' << data_tag << '>'
      result.join
    end
  end
end
