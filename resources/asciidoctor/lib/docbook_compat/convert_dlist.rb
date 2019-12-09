# frozen_string_literal: true

require_relative '../log_util'

module DocbookCompat
  ##
  # Methods to convert lists.
  module ConvertDList
    include LogUtil

    def convert_dlist(node)
      style = node.style || 'vertical'
      node.converter.convert node, "#{style}_dlist"
    rescue NoMethodError
      warn block: node, message: <<~MESSAGE.strip
        Can't convert unknown description list style [#{style}].
      MESSAGE
    end

    def convert_vertical_dlist(node)
      [
        '<div class="variablelist">',
        node.id ? %(<a id="#{node.id}"></a>) : nil,
        '<dl class="variablelist">',
        node.items.map { |terms, dd| Vertical.convert_dlist_item terms, dd },
        '</dl>',
        '</div>',
      ].flatten.compact.join "\n"
    end

    def convert_horizontal_dlist(node)
      node.assign_caption nil, :table
      [
        convert_table_intro(node),
        convert_table_tag(node, 0),
        Horizontal::INTRO,
        node.items.map { |terms, dd| Horizontal.convert_dlist_item terms, dd },
        Horizontal::OUTRO,
        convert_table_outro(node),
      ].flatten
    end

    def convert_qanda_dlist(node)
      [
        QuestionAndAnswer::INTRO,
        node.items.each_with_index.map do |(terms, dd), index|
          QuestionAndAnswer.convert_dlist_item index, terms, dd
        end,
        QuestionAndAnswer::OUTRO,
      ].flatten
    end

    ##
    # Creates a "vertical" style (the default) dlists.
    module Vertical
      def self.convert_dlist_item(terms, definition)
        [
          terms.map { |term| convert_dlist_term term },
          convert_dlist_definition(definition),
        ].flatten
      end

      def self.convert_dlist_term(term)
        [
          '<dt>',
          '<span class="term">',
          term.convert,
          '</span>',
          '</dt>',
        ]
      end

      def self.convert_dlist_definition(definition)
        return unless definition

        ['<dd>', definition.convert, '</dd>']
      end
    end

    ##
    # Creates a "horizontal" style dlists.
    module Horizontal
      INTRO = [
        '<colgroup>',
        '<col/>',
        '<col/>',
        '</colgroup>',
        '<tbody valign="top">',
      ].freeze
      OUTRO = [
        '</tbody>',
        '</table>',
      ].freeze

      def self.convert_dlist_item(terms, definition)
        [
          '<tr>',
          '<td valign="top">',
          terms.map { |term| convert_dlist_term term },
          '</td>',
          convert_dlist_definition(definition),
          '</tr>',
        ].flatten
      end

      def self.convert_dlist_term(term)
        ['<p>', term.convert, '</p>']
      end

      def self.convert_dlist_definition(definition)
        [
          '<td valign="top">',
          '<p>',
          definition&.convert,
          '</p>',
          '</td>',
        ].compact
      end
    end

    ##
    # Creates a "qanda" style dlists.
    module QuestionAndAnswer
      INTRO = [
        '<div class="qandaset">',
        '<table border="0">',
        '<colgroup>',
        '<col align="left" width="1%"/>',
        '<col/>',
        '</colgroup>',
        '<tbody>',
      ].freeze
      OUTRO = [
        '</tbody>',
        '</table>',
        '</div>',
      ].freeze

      def self.convert_dlist_item(index, terms, answer)
        [
          terms.map { |question| convert_dlist_question index, question },
          convert_dlist_answer(answer),
        ].flatten
      end

      def self.convert_dlist_question(index, question)
        [
          '<tr class="question">',
          convert_dlist_index_cell(index),
          '<td align="left" valign="top">',
          '<p>',
          question.convert,
          '</p>',
          '</td>',
          '</tr>',
        ].flatten
      end

      def self.convert_dlist_answer(answer)
        [
          '<tr class="answer">',
          convert_dlist_index_cell(nil),
          '<td align="left" valign="top">',
          '<p>',
          answer&.convert,
          '</p>',
          '</td>',
          '</tr>',
        ].compact
      end

      def self.convert_dlist_index_cell(index)
        [
          '<td align="left" valign="top">',
          index ? "<p><strong>#{index + 1}.</strong></p>" : nil,
          '</td>',
        ].compact
      end
    end
  end
end
