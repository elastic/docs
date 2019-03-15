# frozen_string_literal: true

require_relative '../scaffold.rb'
require_relative 'copier.rb'

module CopyImages
  ##
  # Copies images that are referenced into the same directory as the output files.
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
  #
  class CopyImages < TreeProcessorScaffold
    include Asciidoctor::Logging

    ADMONITION_IMAGE_FOR_REVISION_FLAG = {
      'added' => 'note',
      'changed' => 'note',
      'deleted' => 'warning',
    }.freeze
    CALLOUT_RX = /CO\d+-(\d+)/

    def initialize(name)
      super
      @copier = Copier.new
    end

    def process_block(block)
      process_image block
      process_callout block
      process_admonition block
    end

    def process_image(block)
      return unless block.context == :image

      uri = block.image_uri(block.attr 'target')
      return if Asciidoctor::Helpers.uriish? uri # Skip external images

      @copier.copy_image block, uri
    end

    def process_callout(block)
      callout_extension = block.document.attr 'copy-callout-images'
      return unless callout_extension
      return unless block.parent && block.parent.context == :colist

      coids = block.attr('coids')
      return unless coids

      coids.scan(CALLOUT_RX) do |(index)|
        @copier.copy_image block, "images/icons/callouts/#{index}.#{callout_extension}"
      end
    end

    def process_admonition(block)
      admonition_extension = block.document.attr 'copy-admonition-images'
      return unless admonition_extension

      process_standard_admonition admonition_extension, block
      process_change_admonition admonition_extension, block
    end

    def process_standard_admonition(admonition_extension, block)
      return unless block.context == :admonition

      # The image for a standard admonition comes from the style
      style = block.attr 'style'
      return unless style

      @copier.copy_image block, "images/icons/#{style.downcase}.#{admonition_extension}"
    end

    def process_change_admonition(admonition_extension, block)
      revisionflag = block.attr 'revisionflag'
      return unless revisionflag

      admonition_image = ADMONITION_IMAGE_FOR_REVISION_FLAG[revisionflag]
      if admonition_image
        @copier.copy_image block, "images/icons/#{admonition_image}.#{admonition_extension}"
      else
        logger.warn message_with_context "unknow revisionflag #{revisionflag}", :source_location => block.source_location
      end
    end
  end
end
