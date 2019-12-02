# frozen_string_literal: true

module Chunker
  ##
  # Helpers for making links.
  module Link
    def link_href(target)
      case target.context
      when :section
        %(href="#{target.id}.html")
      when :document
        %(href="index.html")
      else
        raise "Can't link to #{target}"
      end
    end

    def link_text(target)
      case target.context
      when :section
        target.title
      when :document
        target.doctitle(partition: true).main.strip
      else
        raise "Can't link to #{target}"
      end
    end
  end
end
