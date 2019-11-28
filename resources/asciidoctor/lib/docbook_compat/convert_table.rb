# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert tables.
  module ConvertTable
    def convert_table(node)
      [
        '<div class="informaltable">',
        '<table border="1" cellpadding="4px">',
        table_parts(node),
        '</table>',
        '</div>',
      ].flatten.join "\n"
    end

    def table_parts(node)
      head, body, foot = pull_table_parts node
      result = []
      result += table_head head unless head.empty?
      result += table_body body unless body.empty?
      result += table_foot foot unless foot.empty?
      result
    end

    def pull_table_parts(node)
      ((_head, head), (_body, body), (_foot, foot)) = node.rows.by_section
      [head, body, foot]
    end

    def table_head(rows)
      [
        '<thead>',
        rows.map { |row| table_row row, 'th' },
        '</thead>',
      ].flatten
    end

    def table_body(rows)
      [
        '<tbody>',
        rows.map { |row| table_row row, 'td', false },
        '</tbody>',
      ].flatten
    end

    def table_foot(rows)
      [
        '<tbody>',
        rows.map { |row| table_row row, 'td', true },
        '</tbody>',
      ].flatten
    end

    def table_row(row, data_tag, wrap_bare_data)
      [
        '<tr>',
        row.map { |cell| table_cell cell, data_tag, wrap_bare_data },
        '</tr>',
      ].flatten
    end

    def table_cell(cell, data_tag, wrap_bare_data)
      [
        '<', data_tag, ' align="left" valign="top">',
        cell.blocks? nil : '<p>',
        cell.content.join(''),
        cell.blocks? nil : '</p>',
        '</', data_tag, '>'
      ].compact.join
    end
  end
end
