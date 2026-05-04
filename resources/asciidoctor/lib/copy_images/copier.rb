# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'set'
require_relative '../log_util'

module CopyImages
  ##
  # Handles finding images, copying them, and *not* copying them if they have
  # already been copied.
  class Copier
    include LogUtil

    ALLOWED_IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .svg .ico .webp].freeze

    def initialize
      # TODO: store this set on the document so we don't duplicate copies
      # for sub-documents caused by alternative examples
      @copied = Set[]
    end

    def copy_image(block, uri)
      return unless @copied.add? uri      # Skip images we've copied before

      source = find_source block, uri
      return unless source                # Skip images we can't find

      info block: block, message: "copying #{source}"
      copy_image_proc = block.document.attr 'copy_image'
      if copy_image_proc
        # Delegate to a proc for copying if one is defined. Used for testing.
        copy_image_proc.call(uri, source)
      else
        perform_copy block, uri, source
      end
    end

    def perform_copy(block, uri, source)
      unless ALLOWED_IMAGE_EXTENSIONS.include?(File.extname(uri).downcase)
        return warn block: block, message: "Non-image extension: #{uri}"
      end

      if File.symlink?(source)
        return warn block: block, message: "Refusing to copy symlink: #{source}"
      end

      doc = block.document
      outdir = book_outdir doc
      dest = File.expand_path(uri, doc.options[:to_dir])

      unless dest.start_with?("#{outdir}/")
        return warn block: block, message: "Image outside output dir: #{uri}"
      end

      if File.symlink?(dest)
        return warn block: block, message: "Destination is a symlink: #{dest}"
      end

      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp source, dest
    end

    ##
    # Does a breadth first search starting at the base_dir of the document and
    # any referenced resources. This isn't super efficient but it is how a2x
    # works and we strive for compatibility.
    def find_source(block, uri)
      to_check = roots_to_check block
      checked = []

      while (dir = to_check.shift)
        checked << block.normalize_system_path(uri, dir)
        return checked.last if File.readable? checked.last
        next unless Dir.exist?(dir)

        to_check += subdirs(dir)
      end

      log_missing block, checked, uri
      nil
    end

    ##
    # The directory roots to check for the file to copy
    def roots_to_check(block)
      to_check = [block.document.base_dir]

      resources = block.document.attr 'resources'
      return to_check unless resources
      return to_check if resources.empty?

      to_check + CSV.parse_line(resources)
    rescue CSV::MalformedCSVError => error
      error block: block, message: "Error loading [resources]: #{error}"
      to_check
    end

    def subdirs(dir)
      Dir.new(dir)
         .reject { |f| ['.', '..'].include? f }
         .map { |f| File.join dir, f }
         .select { |f| File.directory?(f) }
    end

    ##
    # Log a warning for files that we couldn't find.
    def log_missing(block, checked, uri)
      # Sort the list of directories we did check so it is consistent from
      # machine to machine. This is mostly useful for testing, but it nice
      # if you happen to want to compare CI to a local machine.
      checked.sort! do |lhs, rhs|
        by_depth = lhs.scan(%r{/}).count <=> rhs.scan(%r{/}).count
        if by_depth != 0
          by_depth
        else
          lhs <=> rhs
        end
      end
      warn block: block,
           message: "can't read image [#{uri}] at any of #{checked}"
    end

    private

    def book_outdir(doc)
      raw = doc.attr('outdir') || doc.options[:to_dir]
      File.expand_path(File.dirname(raw))
    end
  end
end
