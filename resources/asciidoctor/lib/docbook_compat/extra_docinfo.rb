# frozen_string_literal: true

module DocbookCompat
  ##
  # Adds extra meta stuff to the <head> and header
  module ExtraDocinfo
    def docinfo(location = :head, suffix = nil)
      case location
      when :head
        super + extra_docbook_compat_head
      else
        super
      end
    end

    private

    def extra_docbook_compat_head
      <<~HTML
        <meta name="DC.type" content="#{attributes['dc.type']}"/>
        <meta name="DC.subject" content="#{attributes['dc.subject']}"/>
        <meta name="DC.identifier" content="#{attributes['dc.identifier']}"/>
      HTML
    end
  end
end
