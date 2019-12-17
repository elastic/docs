# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'
require_relative '../log_util'
require_relative 'copier'

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
    include LogUtil

    def initialize(delegate)
      super(delegate)
      @copier = Copier.new
    end

    #### "Conversion" methods
    def convert_image(node)
      copy_image node, node.image_uri(node.attr('target'))
      yield
    end

    def convert_inline_image(node)
      # Inline images aren't "real" and don't have a source_location so we have
      # to get the location from the parent.
      copy_image node.parent, node.image_uri(node.target)
      yield
    end

    #### Helper methods
    def copy_image(node, uri)
      return unless uri
      return if Asciidoctor::Helpers.uriish? uri # Skip external images

      @copier.copy_image node, uri
    end
  end
end
