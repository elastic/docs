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
        # Elastic
        elastic_compat_meta('product_name', attributes['dc.subject']),
        elastic_compat_meta('product_version', attributes['dc.identifier']),
        elastic_compat_meta('website_area', attributes['dc.prefix']),
        elastic_compat_meta('source_branch', attributes['source_branch']),
        elastic_compat_meta('current', attributes['current']),

        if attributes['source_branch'] == attributes['current']
          elastic_compat_meta('is_current_product_version', 100)
        else
          elastic_compat_meta('is_current_product_version', 0)
        end,

        docbook_compat_meta('DC.type', attributes['dc.type']),
        docbook_compat_meta('DC.subject', attributes['dc.subject']),
        docbook_compat_meta('DC.identifier', attributes['dc.identifier']),
        if attributes['noindex']
          docbook_compat_meta('robots', 'noindex,nofollow')
        end,
      ].compact.join "\n"
    end

    def docbook_compat_meta(name, content)
      %(<meta name="#{name}" content="#{content}"/>)
    end
    def elastic_compat_meta(name, content)
      %(<meta class="elastic" name="#{name}" content="#{content}"/>)
    end
  end
end
