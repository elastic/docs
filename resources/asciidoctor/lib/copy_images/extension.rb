require 'csv'
require 'fileutils'
require 'set'
require_relative '../scaffold.rb'

include Asciidoctor

##
# Copies images that are referenced into the same directory as the output files.
#
class CopyImages < TreeProcessorScaffold
  include Logging

  def initialize name
    super
    @copied = Set[]
  end

  def process_block block
    if block.context == :image
      uri = block.image_uri(block.attr 'target')
      return if Helpers.uriish? uri # Skip external images
      copy_image block, uri
    else
      extension = block.attr 'copy-callout-images'
      if extension && block.parent && block.parent.context == :colist
        id = block.attr('coids').scan(/CO(?:\d+)-(\d+)/) {
          copy_image block, "images/icons/callouts/#{$1}.#{extension}"
        }
      end
    end
  end

  def copy_image block, uri
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
  def find_source block, uri
    to_check = [block.document.base_dir]
    checked = []

    resources = block.document.attr 'resources'
    if resources
      to_check += CSV.parse_line(resources)
    end

    while (dir = to_check.shift)
      checked << block.normalize_system_path(uri, dir)
      return checked.last if File.readable? checked.last
      next unless Dir.exist?(dir)
      Dir.new(dir).each { |f|
        next if f == '.' || f == '..'
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
