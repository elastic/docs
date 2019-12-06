# frozen_string_literal: true

require_relative '../scaffold'

module DocbookCompat
  ##
  # Looks for pass blocks with `<titleabbrev>` and adds an attributes to their
  # parent section. This attribute is an abbreviated title used when rendering
  # the table of contents. This exists entirely for backwards compatibility with
  # docbook. It is simpler and recommended to set the `reftext` attribute
  # directly on the section when the document is built with `--direct_html`.
  class TitleabbrevHandler < TreeProcessorScaffold
    def process_block(block)
      return unless block.context == :pass

      process_pass block
    end

    def process_pass(block)
      text = block.lines.join "\n"
      return unless (m = text.match %r{<titleabbrev>([^<]+)</titleabbrev>\n?}m)

      text.slice! m.begin(0), m.end(0)
      block.lines = text.split "\n"
      process_titleabbrev block, m[1]
    end

    private

    def process_titleabbrev(block, reftext)
      section = block.parent
      section = section.parent until section.context == :section
      # Docbook seems to bold links to sections less than 2 so we should too.
      reftext = "_#{reftext}_" if section.level < 2
      section.attributes['reftext'] = reftext
    end
  end
end
