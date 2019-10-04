# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'

##
# Converts absolute links to some url root into relative links.
module RelativizeLink
  def self.activate(registry)
    DelegatingConverter.setup(registry.document) do |doc|
      Converter.new doc
    end
  end

  ##
  # Converter implementation that does the conversion.
  class Converter < DelegatingConverter
    def inline_anchor(node)
      modify node
      yield
    end

    def modify(node)
      return unless node.type == :link
      return unless (root = node.attr 'relativize-link')
      return unless node.target.start_with? root

      node.target = '/' + node.target[root.length..node.target.length]
    end
  end
end
