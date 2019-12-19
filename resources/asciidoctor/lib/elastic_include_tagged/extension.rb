# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../log_util'

# Extension to emulate Elastic's asciidoc customization to include tagged
# portions of a file. While it was originally modeled after asciidoctor's
# behavior it was never entirely compatible.
#
# Usage
#
#   include:elastic-include-tagged:{doc-tests}/Foo.java[tag]
#
class ElasticIncludeTagged < Asciidoctor::Extensions::IncludeProcessor
  def handles?(target)
    /^elastic-include-tagged:/.match target
  end

  def process(doc, reader, target, attrs)
    target = target.sub(/^elastic-include-tagged:/, '')

    Includer.new(doc, reader, target, attrs).include_lines
  end

  ##
  # Helper to include lines.
  class Includer
    include LogUtil

    def initialize(doc, reader, target, attrs)
      @reader = reader
      @target = target
      @tag = attrs[1]
      @attrs = attrs
      @path = doc.normalize_system_path(
        target, reader.dir, nil, target_name: 'include file'
      )
      @relpath = doc.path_resolver.relative_path @path, doc.base_dir
      init_regexes
      init_state
    end

    # These are used when scanning the file
    def init_regexes
      @start_match = /^(\s*).+tag::#{@tag}\b/
      @end_match = /end::#{@tag}\b/
    end

    # These are modified when scanning the file
    def init_state
      @lines = []
      @start_of_include = nil
      @found_end = false
    end

    ##
    # Perform the actual include and return nil if it is successful or return
    # a stand in line if it wasn't. Always logs a warning when returning a
    # stand in line, sometimes logs one when the inclusion is *partially*
    # successful.
    def include_lines
      if @attrs.size != 1
        warn "elastic-include-tagged expects only a tag but got: #{@attrs}"
        return @target
      end

      return @path unless read_file && check_markers

      @reader.push_include @lines, @path, @relpath, @start_of_include, @attrs
    end

    ##
    # Read the file. Returns true if we successfully read the file, nil
    # otherwise.
    def read_file
      File.open(@path, 'r:UTF-8') { |f| @found_end = scan_file f }
      true
    rescue Errno::ENOENT
      error message: "include file not found: #{@path}",
            location: @reader.cursor
    rescue IOError => e
      warn "error including [#{e.message}]"
    end

    ##
    # Check the markers for a successful read. Returns true if we got
    # *something*, false otherwise.
    def check_markers
      if @start_of_include.nil?
        warn "missing start tag [#{@tag}]"
        return false
      end
      unless @found_end
        warn "missing end tag [#{@tag}]", Asciidoctor::Reader::Cursor.new(
          @path, @relpath, @relpath, @start_of_include
        )
      end
      true
    end

    ##
    # Scan the file for the lines, populating instance variables along the way.
    # Returns true if we found the end of the file, false otherwise.
    def scan_file(file)
      indentation = nil
      file.each_line.with_index do |line, index|
        if indentation
          return true if @end_match =~ line

          @lines << line.sub(indentation, '')
        else
          indentation = scan_for_start line, index
        end
      end
      false
    end

    ##
    # Scans a line for the start of a match. Returns the indentation cleanup
    # regex if we find the start, nil otherwise.
    def scan_for_start(line, index)
      return unless (start_match_data = @start_match.match line)

      @start_of_include = index + 1
      /^#{start_match_data[1]}/
    end

    def warn(message, cursor = @reader.cursor)
      logger.warn message_with_context message, source_location: cursor
    end
  end
end
