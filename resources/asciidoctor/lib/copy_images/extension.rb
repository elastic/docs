# frozen_string_literal: true

require_relative '../delegating_conveter.rb'
require_relative 'copier.rb'

##
# Copies images that are referenced into the same directory as the
# output files.
#
# It finds the images by looking in a comma separated list of directories
# defined by the `resources` attribute.
#
# It can also be configured to copy the images that number callout lists by
# setting `copy-callout-images` to the file extension of the images to copy.
#
# It can also be configured to copy the that decoration admonitions by
# setting `copy-admonition-images` to the file extension of the images
# to copy.
module CopyImages
  def self.activate(registry)
    DelegatingConverter.setup(registry.document) { |doc| Converter.new doc }
  end

  ##
  # A Converter implementation that copies images as it sees them.
  class Converter < DelegatingConverter
    include Asciidoctor::Logging

    ADMONITION_IMAGE_FOR_REVISION_FLAG = {
      'added' => 'note',
      'changed' => 'note',
      'deleted' => 'warning',
    }.freeze
    CALLOUT_RX = /CO\d+-(\d+)/
    INLINE_IMAGE_RX = /(\\)?image:([^:\s\[](?:[^\n\[]*[^\s\[])?)\[/m
    DOCBOOK_IMAGE_RX = %r{<imagedata fileref="([^"]+)"/>}m

    def initialize(delegate)
      super(delegate)
      @copier = Copier.new
    end

    #### "Conversion" methods

    def admonition(node)
      if (extension = node.attr 'copy-admonition-images') &&
         (style = node.attr 'style')
        # The image for a standard admonition comes from the style
        path = "images/icons/#{style.downcase}.#{extension}"
        @copier.copy_image node, path
      end
      yield
    end

    def colist(node)
      if (extension = node.attr 'copy-callout-images')
        node.items.each do |item|
          copy_image_for_callout_items extension, item
        end
      end
      scan_images_from_docbook node, yield
    end

    def dlist(node)
      scan_images_from_docbook node, yield
    end

    def image(node)
      copy_image node, node.attr('target')
      yield
    end

    def olist(node)
      scan_images_from_docbook node, yield
    end

    def paragraph(node)
      scan_images_from_docbook node, yield
    end

    def ulist(node)
      scan_images_from_docbook node, yield
    end

    #### Helper methods

    def scan_images_from_docbook(node, text)
      text.scan(DOCBOOK_IMAGE_RX) do |(uri)|
        copy_image node, uri
      end
      text
    end

    def copy_image(node, uri)
      return unless uri
      return if Asciidoctor::Helpers.uriish? uri # Skip external images

      @copier.copy_image node, uri
    end

    def copy_image_for_callout_items(callout_extension, node)
      coids = node.attr('coids')
      return unless coids

      coids.scan(CALLOUT_RX) do |(index)|
        path = "images/icons/callouts/#{index}.#{callout_extension}"
        @copier.copy_image node, path
      end
    end

    def process_change_admonition(admonition_extension, block)
      revisionflag = block.attr 'revisionflag'
      return unless revisionflag

      admonition_image = ADMONITION_IMAGE_FOR_REVISION_FLAG[revisionflag]
      if admonition_image
        @copier.copy_image(
          block, "images/icons/#{admonition_image}.#{admonition_extension}"
        )
      else
        logger.warn(
          message_with_context(
            "unknow revisionflag #{revisionflag}",
            source_location: block.source_location
          )
        )
      end
    end
  end
end
