# frozen_string_literal: true

module DocbookCompat
  ##
  # Adds extra meta stuff to the <head> and header
  module ExtraDocinfo
    def docinfo(location = :head, suffix = nil)
      case location
      when :head
        [super, extra_docbook_compat_head].compact.join "\n"
      else
        super
      end
    end

    private

    def extra_docbook_compat_head
      [
        docbook_compat_meta('DC.type', attributes['dc.type']),
        docbook_compat_meta('DC.subject', attributes['dc.subject']),
        docbook_compat_meta('DC.identifier', attributes['dc.identifier']),
        attributes['noindex'] && docbook_compat_meta('robots', 'noindex,nofollow'),
      ].compact.join "\n"
    end

    def docbook_compat_meta(name, content)
      %(<meta name="#{name}" content="#{content}"/>)
    end
  end
end
