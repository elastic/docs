# frozen_string_literal: true

require_relative '../strip_tags'
require_relative 'link'

module Chunker
  ##
  # Adds extra tags <link> tags to the <head> to emulate docbook.
  module ExtraDocinfo
    include Link
    include StripTags

    def docinfo(location = :head, suffix = nil)
      info = super
      info += extra_chunker_head if location == :head
      info
    end

    private

    def extra_chunker_head
      [
        %(<link rel="home" href="index.html" title="#{attributes['home']}"/>),
        link_rel('up', attributes['up_section']),
        link_rel('prev', attributes['prev_section']),
        link_rel('next', attributes['next_section']),
        link_rel('canonical', attributes['canonical-url']),
      ].compact.join "\n"
    end

    def link_rel(rel, related)
      return unless related

      if related.is_a?(String)
        %(<link rel="#{rel}" href="#{related}"/>)
      else
        extra = related.context == :document ? related.attr('title-extra') : ''
        title = "#{strip_tags(link_text(related))}#{extra}"
        # We're in an attribute so escape quotes too!
        title = title.gsub '"', '&quot;'
        %(<link rel="#{rel}" #{link_href related} title="#{title}"/>)
      end
    end
  end
end
