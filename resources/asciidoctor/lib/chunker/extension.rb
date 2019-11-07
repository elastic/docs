# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'

##
# HTML5 converter that chunks like docbook.
module Chunker
  def self.activate(registry)
    return unless registry.document.attr 'outdir'
    return unless registry.document.attr 'chunk_level'

    DelegatingConverter.setup(registry.document) { |d| Converter.new d }
  end

  ##
  # A Converter implementation that copies images as it sees them.
  class Converter < DelegatingConverter
    def initialize(delegate)
      super(delegate)
    end

    # TODO: tests don't seem to pick up the headers because "embedded". Bad?

    def convert_section(node)
      chunk_level = node.document.attr 'chunk_level'
      return yield unless node.level == chunk_level

      target = write node, node.id, yield
      link_opts = {
        type: :link,
        target: target,
      }
      node.document.register :links, target
      link = Asciidoctor::Inline.new node, :anchor, node.title, link_opts
      # <div class="toc"><ul class="toc">
      %(<li><span class="chapter">#{link.convert}</span></li>)
    end

    def write(node, target, output)
      dir = node.document.attr 'outdir'
      file = "#{target}.html"
      path = File.join dir, file
      File.open path, 'w:UTF-8' do |f|
        f.write output
      end
      file
    end
  end
end
