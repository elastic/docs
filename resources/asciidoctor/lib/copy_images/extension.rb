# frozen_string_literal: true

require_relative '../delegating_converter.rb'
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

    def initialize(delegate)
      super(delegate)
      @copier = Copier.new
    end

    #### "Conversion" methods

    def admonition(node)
      if (extension = node.attr 'copy-admonition-images')
        if (image = admonition_image node)
          path = "images/icons/#{image}.#{extension}"
          @copier.copy_image node, path
        end
      end
      yield
    end

    def colist(node)
      if (extension = node.attr 'copy-callout-images')
        node.items.each do |item|
          copy_image_for_callout_items extension, item
        end
      end
      yield
    end

    def image(node)
      copy_image node, node.attr('target')
      yield
    end

    def inline_image(node)
      # Inline images aren't "real" and don't have a source_location so we have
      # to get the location from the parent.
      copy_image node.parent, node.target
      yield
    end

    #### Helper methods
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

    def admonition_image(node)
      if (revisionflag = node.attr 'revisionflag')
        image = ADMONITION_IMAGE_FOR_REVISION_FLAG[revisionflag]
        return image if image

        logger.warn(
          message_with_context(
            "unknow revisionflag #{revisionflag}",
            source_location: node.source_location
          )
        )
        return
      end
      # The image for a standard admonition comes from the style
      style = node.attr 'style'
      style&.downcase
    end
  end
end
