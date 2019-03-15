# frozen_string_literal: true

require 'fileutils'

require_relative '../scaffold.rb'

##
# Extensions for enriching certain source blocks with "OPEN IN CONSOLE",
# "OPEN IN SENSE", "OPEN IN KIBANA", AND/OR "COPY_AS_CURL".
#
# Usage
#
#   [source,console]
#   ---------
#   GET /
#   ---------
#
# or
#
#   [source,sense]
#   ---------
#   GET /
#   ---------
#
# or
#
#   [source,kibana]
#   ---------
#   GET /
#   ---------
#
# or
#
#   [source,sense,snippet=path/to/snippet.console]
#   ---------
#   GET /
#   ---------
#
class OpenInWidget < TreeProcessorScaffold
  include Asciidoctor::Logging

  CALLOUT_SCAN_RX = / ?#{Asciidoctor::CalloutScanRx}/

  def process_block(block)
    return unless block.context == :listing && block.style == 'source'

    lang = block.attr 'language'
    return unless %w[console sense kibana].include? lang

    snippet = block.attr 'snippet'
    if snippet
      # If you specify the snippet path then we should copy it into the
      # destination directory so it is available for Kibana.
      snippet_path = "snippets/#{snippet}"
      normalized = block.normalize_system_path(snippet_path, block.document.base_dir)
      if File.readable? normalized
        copy_snippet block, normalized, snippet_path
        logger.warn message_with_context "reading snippets from a path makes the book harder to read", :source_location => block.source_location
      else
        logger.error message_with_context "can't read snippet from #{normalized}", :source_location => block.source_location
      end
    else
      # If you don't specify the snippet then we assign it a number and read
      # the contents of the source listing, copying it to the destination
      # directory so it is available for Kibana.
      snippet_number = block.document.attr 'snippet_number', 1
      snippet = "#{snippet_number}.#{lang}"
      block.document.set_attr 'snippet_number', snippet_number + 1

      snippet_path = "snippets/#{snippet}"
      source = block.source.gsub(CALLOUT_SCAN_RX, '') + "\n"
      write_snippet block, source, snippet_path
    end
    block.set_attr 'snippet_link', "<ulink type=\"snippet\" url=\"#{snippet_path}\"/>"
    block.document.register :links, snippet_path

    def block.content
      "#{@attributes['snippet_link']}#{super}"
    end
  end

  def copy_snippet(block, source, uri)
    logger.info message_with_context "copying snippet #{source}", :source_location => block.source_location
    copy_proc = block.document.attr 'copy_snippet'
    if copy_proc
      # Delegate to a proc for copying if one is defined. Used for testing.
      copy_proc.call(uri, source)
    else
      destination = ::File.join block.document.options[:to_dir], uri
      destination_dir = ::File.dirname destination
      FileUtils.mkdir_p destination_dir
      FileUtils.cp source, destination
    end
  end

  def write_snippet(block, snippet, uri)
    logger.info message_with_context "writing snippet #{uri}", :source_location => block.source_location
    write_proc = block.document.attr 'write_snippet'
    if write_proc
      # Delegate to a proc for copying if one is defined. Used for testing.
      write_proc.call(uri, snippet)
    else
      destination = ::File.join block.document.options[:to_dir], uri
      destination_dir = ::File.dirname destination
      FileUtils.mkdir_p destination_dir
      File.open(destination, 'w') { |file| file.write(snippet) }
    end
  end
end
