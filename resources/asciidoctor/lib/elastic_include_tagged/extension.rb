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
  include Asciidoctor::Logging

  def handles?(target)
    /^elastic-include-tagged:/.match target
  end

  def process(_doc, reader, target, attrs)
    target = target.sub(/^elastic-include-tagged:/, '')
    if attrs.size != 1
      logger.warn message_with_context %(elastic-include-tagged expects only a tag but got: #{attrs}), :source_location => reader.cursor
      return target
    end
    tag = attrs[1]
    start_match = /^(\s*).+tag::#{tag}\b/
    end_match = /end::#{tag}\b/

    path, target_type, relpath = reader.resolve_include_path target, attrs, attrs
    # resolve_include_path returns a nil target_type if it can't find the file
    # and it logs a nice error for us
    return path unless target_type

    included_lines = []
    start_of_include = nil
    found_end = false
    begin
      File.open(path, 'r') do |file|
        lineno = 0
        found_tag = false
        indentation = nil
        file.each_line do |line|
          lineno += 1
          line.force_encoding Encoding::UTF_8
          if end_match =~ line
            found_end = true
            break
          end
          if found_tag
            line = line.sub(indentation, '')
            included_lines << line if line
            next
          end
          start_match_data = start_match.match(line)
          next unless start_match_data

          found_tag = true
          indentation = /^#{start_match_data[1]}/
          start_of_include = lineno
        end
      end
    rescue IOError => e
      warn reader.cursor, "error including [#{e.message}]"
      return path
    end
    if start_of_include.nil?
      warn reader.cursor, "missing start tag [#{tag}]"
      return path
    end
    if found_end == false
      warn Asciidoctor::Reader::Cursor.new(path, relpath, relpath, start_of_include),
          "missing end tag [#{tag}]"
    end
    reader.push_include included_lines, path, relpath, start_of_include, attrs
  end

  def warn(cursor, message)
    logger.warn message_with_context %(elastic-include-tagged #{message}), :source_location => cursor
  end
end
