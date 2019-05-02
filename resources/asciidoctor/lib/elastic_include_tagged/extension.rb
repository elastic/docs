# frozen_string_literal: true

require 'asciidoctor/extensions'

# Extension to emulate Elastic's asciidoc customization to include tagged
# portions of a file. While it was originally modeled after asciidoctor's
# behavior it was never entirely compatible.
#
# Usage
#
#   include:elastic-include-tagged:{doc-tests}/RestClientDocumentation.java[rest-client-init]
#
class ElasticIncludeTagged < Asciidoctor::Extensions::IncludeProcessor
  def handles?(target)
    /^elastic-include-tagged:/.match target
  end

  def process(_doc, reader, target, attrs)
    target = target.sub(/^elastic-include-tagged:/, '')

    Includer.new(reader, target, attrs).include_lines
  end

  ##
  # Helper to include lines.
  class Includer
    include Asciidoctor::Logging

    def initialize(reader, target, attrs)
      @reader = reader
      @target = target
      @tag = attrs[1]
      @attrs = attrs
      # resolve_include_path returns the path if can't resolve the file and logs
      # the error.
      @path, _target_type, @relpath = reader.resolve_include_path(
        target, attrs, attrs
      )

      # These are used when scanning the file
      @start_match = /^(\s*).+tag::#{@tag}\b/
      @end_match = /end::#{@tag}\b/

      # These are modified when scanning the file
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
      return @path unless @relpath

      begin
        File.open(@path, 'r') { |f| scan_file(f) }
      rescue IOError => e
        warn "error including [#{e.message}]"
        return @path
      end
      if @start_of_include.nil?
        warn "missing start tag [#{@tag}]"
        return @path
      end
      if @found_end == false
        warn "missing end tag [#{@tag}]", Asciidoctor::Reader::Cursor.new(
          @path, @relpath, @relpath, @start_of_include
        )
      end
      @reader.push_include @lines, @path, @relpath, @start_of_include, @attrs
    end

    ##
    # Scan the file for the lines, populating instance variables along the way.
    def scan_file(file)
      lineno = 0
      found_tag = false
      indentation = nil
      file.each_line do |line|
        lineno += 1
        line.force_encoding Encoding::UTF_8
        if @end_match =~ line
          @found_end = true
          break
        end
        if found_tag
          line = line.sub(indentation, '')
          @lines << line if line
          next
        end
        start_match_data = @start_match.match(line)
        next unless start_match_data

        found_tag = true
        indentation = /^#{start_match_data[1]}/
        @start_of_include = lineno
      end
    end

    def warn(message, cursor = @reader.cursor)
      logger.warn message_with_context message, source_location: cursor
    end
  end
end
