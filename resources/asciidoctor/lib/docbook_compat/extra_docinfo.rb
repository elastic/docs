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

      # Allows :meta-product-name: to overwrite the product name
      product_name = attributes['meta-product-name'] ?
        attributes['meta-product-name'] :
        attributes['dc.subject']
      # Uses docdir attr to match final portion of string after `en/`
      website_area = attributes['docdir'].scan(%r{(?<=en\/).*}i)[0].to_s
      # Assigns the arbitrary value of 100 if the branch built is "current"
      current_version_val =
        attributes['source_branch'] == attributes['current'] ? 100 : 0
      # Keeping this for now but will remove later
      # current_version_val = attributes['is-current-version'] ? (100) : (0)

      [
        # Working
        elastic_compat_meta('website_area', website_area),
        elastic_compat_meta('product_version', attributes['dc.identifier']),
        elastic_compat_meta('product_name', product_name),
        elastic_compat_meta('is_current_product_version', current_version_val),

        # Not working
        elastic_compat_meta('content', 'this is blank for now'),
        elastic_compat_meta('thumbnail_image', 'this is blank for now'),

        # Legacy docbook meta
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
