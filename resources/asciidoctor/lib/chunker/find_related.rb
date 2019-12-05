# frozen_string_literal: true

module Chunker
  ##
  # Looks for "related" pages to satisfy docbook's `next`, `prev`,
  # and `up` links.
  module FindRelated
    def find_related(section)
      return {} unless (index = section.parent.blocks.find_index section)

      {
        'up_section' => section.parent,
        'prev_section' => find_prev_in(section.parent, index - 1),
        'next_section' => find_next(section, index),
      }
    end

    ##
    # Find the page that comes before the page at `parent.blocks[index + 1]` in
    # "table of contents order".
    def find_prev_in(parent, index)
      while index >= 0
        c = parent.blocks[index]
        if c.context == :section
          return c if c.level == @chunk_level

          parent = c
          index = c.blocks.length
        end
        index -= 1
      end
      # index was for the first section in the parent so the previous page
      # *is* the parent.
      parent
    end

    def find_next(section, index)
      if section.level < @chunk_level
        find_next_in section, 0
      else
        find_next_in section.parent, index + 1
      end
    end

    ##
    # Find the page that comes after the page at `parent.blocks[index - 1]` in
    # "table of contents order".
    def find_next_in(parent, index)
      loop do
        while (c = parent.blocks[index])
          return c if c.context == :section && c.level <= @chunk_level

          index += 1
        end
        return unless parent.parent
        return unless (index = parent.parent.blocks&.find_index parent)

        parent = parent.parent
        index += 1
      end
    end
  end
end
