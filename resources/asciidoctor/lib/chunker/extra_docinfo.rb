# frozen_string_literal: true

module Chunker
  ##
  # Adds extra tags <link> tags to the <head> to emulate docbook.
  module ExtraDocinfo
    def docinfo(location = :head, suffix = nil)
      info = super
      info += extra_head if location == :head
      info
    end

    def extra_head
      [
        %(<link rel="home" href="index.html" title="#{attributes['home']}"/>),
        link_rel('up', attributes['up_section']),
        link_rel('prev', attributes['prev_section']),
        link_rel('next', attributes['next_section']),
      ].compact.join "\n"
    end

    def link_rel(rel, related)
      return unless related

      id = rel_id related
      title = rel_title related
      %(<link rel="#{rel}" href="#{id}.html" title="#{title}"/>)
    end

    def rel_id(related)
      case related.context
      when :section
        related.id
      when :document
        'index'
      else
        raise "Can't link to #{related}"
      end
    end

    def rel_title(related)
      case related.context
      when :section
        related.title
      when :document
        related.doctitle(partition: true).main.strip
      else
        raise "Can't link to #{related}"
      end
    end
  end
end
