# frozen_string_literal: true

require_relative '../scaffold'

module DocbookCompat
  ##
  # Looks for pass blocks with `<titleabbrev>` and adds an attributes to their
  # parent section that is an abbreviated title usesd when rendering the
  # when rendering the table of contents. This exists entirely for backwards
  # compatibility with docbook. It is simpler and recommended to set the
  # `titleabbrev` attribute directly on the section when the document is built
  # with `--direct_html`.
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

      section = block.parent
      section = section.parent until section.context == :section
      section.attributes['titleabbrev'] = m[1]
    end
  end
end
