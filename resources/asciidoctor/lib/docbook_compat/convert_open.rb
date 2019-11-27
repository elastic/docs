# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert open blocks.
  module ConvertOpen
    def convert_open(node)
      # If the open block is *totally* unadorned then it is entirely invisible.
      return yield unless node.style == 'open'
      return yield if node.id
      return yield if node.title?

      node.content
    end
  end
end
