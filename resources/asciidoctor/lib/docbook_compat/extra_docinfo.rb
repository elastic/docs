# frozen_string_literal: true

module DocbookCompat
  ##
  # Adds extra meta stuff to the <head> and header
  module ExtraDocinfo
    def docinfo(location = :head, suffix = nil)
      case location
      when :head
        [super, meta_head].compact.join "\n"
      else
        super
      end
    end

    private

    def meta_head
      [
        extra_elastic_head,
        extra_docbook_compat_head,
      ].compact.join "\n"
    end

    def extra_elastic_head
      [
        # Elastic meta
        elastic_compat_meta('product_version', attributes['dc.identifier']),
        elastic_compat_meta('product_name', product_name),
        elastic_compat_meta('website_area', 'documentation'),
      ]
    end

    def extra_docbook_compat_head
      [
        # Legacy docbook meta
        docbook_compat_meta('DC.type', attributes['dc.type']),
        docbook_compat_meta('DC.subject', attributes['dc.subject']),
        docbook_compat_meta('DC.collection', attributes['dc.collection']),
        docbook_compat_meta('DC.group', attributes['dc.group']),
        docbook_compat_meta('DC.book_id', attributes['dc.book_id']),
        docbook_compat_meta('DC.current', attributes['dc.current']),
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

    def product_name
      attributes['meta-product-name'] || attributes['dc.subject']
    end

    def page_title
      attributes['docdir'].scan(%r{(?<=en\/).*}i)[0].to_s
    end
  end
end
