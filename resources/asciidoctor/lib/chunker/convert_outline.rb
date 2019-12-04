# frozen_string_literal: true

module Chunker
  ##
  # Clean up the generated outline.
  module ConvertOutline
    def convert_outline(node, opts = {})
      # Fix links in the toc
      toclevels = opts[:toclevels] || node.document.attributes['toclevels'].to_i
      outline = yield
      cleanup_outline outline, node, toclevels
      outline
    end

    private

    def cleanup_outline(outline, node, toclevels)
      node.sections.each do |section|
        next if section.roles.include? 'exclude'

        outline.gsub!(%(href="##{section.id}"), %(href="#{section.id}.html")) ||
          raise("Couldn't fix section link for #{section.id} in #{outline}")
        cleanup_outline outline, section, toclevels if section.level < toclevels
      end
    end
  end
end
