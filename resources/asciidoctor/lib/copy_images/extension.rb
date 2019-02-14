require 'csv'
require 'fileutils'
require 'set'
require_relative '../scaffold.rb'

include Asciidoctor

##
# Copies images that are referenced into the same directory as the output files.
#
# It finds the images by looking in a comma separated list of directories
# defined by the `resources` attribute.
#
# It can also be configured to copy the images that number callout lists by
# setting `copy-callout-images` to the file extension of the images to copy.
#
class CopyImages < TreeProcessorScaffold
  include Logging
  ADMONITION_IMAGE_FOR_REVISION_FLAG = {
    'added' => 'note',
    'changed' => 'note',
    'deleted' => 'warning',
  }

  def initialize(name)
    super
    @copied = Set[]
  end

  def process_block(block)
    if block.context == :image
      uri = block.image_uri(block.attr 'target')
      return if Helpers.uriish? uri # Skip external images

      copy_image block, uri
      return
    end
    callout_extension = block.document.attr 'copy-callout-images'
    if callout_extension
      if block.parent && block.parent.context == :colist
        coids = block.attr('coids')
        return unless coids

        coids.scan(/CO(?:\d+)-(\d+)/) {
          copy_image block, "images/icons/callouts/#{$1}.#{callout_extension}"
        }
        return
      end
    end
    admonition_extension = block.document.attr 'copy-admonition-images'
    if admonition_extension
      if block.context == :admonition
        # The image for a standard admonition comes from the style
        style = block.attr 'style'
        return unless style

        copy_image block, "images/icons/#{style.downcase}.#{admonition_extension}"
        return
      end
      # The image for a change admonition comes from the revisionflag
      revisionflag = block.attr 'revisionflag'
      if revisionflag
        admonition_image = ADMONITION_IMAGE_FOR_REVISION_FLAG[revisionflag]
        if admonition_image
          copy_image block, "images/icons/#{admonition_image}.#{admonition_extension}"
        else
          logger.warn message_with_context "unknow revisionflag #{revisionflag}", :source_location => block.source_location
        end
        return
      end
    end
  end

  def copy_image(block, uri)
    return unless @copied.add? uri      # Skip images we've copied before

    source = find_source block, uri
    return unless source                # Skip images we can't find

    logger.info message_with_context "copying #{source}", :source_location => block.source_location
    copy_image_proc = block.document.attr 'copy_image'
    if copy_image_proc
      # Delegate to a proc for copying if one is defined. Used for testing.
      copy_image_proc.call(uri, source)
    else
      destination = ::File.join block.document.options[:to_dir], uri
      destination_dir = ::File.dirname destination
      FileUtils.mkdir_p destination_dir
      FileUtils.cp source, destination
    end
  end

  ##
  # Does a breadth first search starting at the base_dir of the document and
  # any referenced resources. This isn't super efficient but it is how a2x works
  # and we strive for compatibility.
  #
  def find_source(block, uri)
    to_check = [block.document.base_dir]
    checked = []

    resources = block.document.attr 'resources'
    if resources && !resources.empty?
      begin
        to_check += CSV.parse_line(resources)
      rescue CSV::MalformedCSVError => error
        logger.error message_with_context "Error loading [resources]: #{error}",
            :source_location => block.source_location
      end
    end

    while (dir = to_check.shift)
      checked << block.normalize_system_path(uri, dir)
      return checked.last if File.readable? checked.last
      next unless Dir.exist?(dir)

      Dir.new(dir).each { |f|
        next if ['.', '..'].include? f

        f = File.join(dir, f)
        to_check << f if File.directory?(f)
      }
    end

    # We'll skip images we can't find but we should log something about it so
    # we can fix them.
    logger.warn message_with_context "can't read image at any of #{checked}", :source_location => block.source_location
    nil
  end
end
