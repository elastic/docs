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
    snippet_path =
      if snippet
        handle_override_snippet block, snippet
      else
        handle_implicit_snippet block, lang
      end
    block.set_attr 'snippet_link',
      "<ulink type=\"snippet\" url=\"#{snippet_path}\"/>"
    block.document.register :links, snippet_path

    def block.content
      "#{@attributes['snippet_link']}#{super}"
    end
  end

  ##
  # Copy explicitly configured snippets to the right path so kibana can pick
  # them up and warn the user that they are lame.
  def handle_override_snippet(block, snippet)
    snippet_path = "snippets/#{snippet}"
    normalized = block.normalize_system_path(snippet_path,
      block.document.base_dir)
    if File.readable? normalized
      copy_override_snippet block, normalized, snippet_path
      message = "reading snippets from a path makes the book harder to read"
      logger.warn message_with_context message,
        source_location: block.source_location
    else
      logger.error message_with_context "can't read snippet from #{normalized}",
        source_location: block.source_location
    end
    snippet_path
  end

  ##
  # Handles non-override snippets by assigning them a number and copying them
  # some place that kibana can read them.
  def handle_implicit_snippet(block, lang)
    snippet_number = block.document.attr 'snippet_number', 1
    snippet = "#{snippet_number}.#{lang}"
    block.document.set_attr 'snippet_number', snippet_number + 1

    snippet_path = "snippets/#{snippet}"
    source = block.source.gsub(CALLOUT_SCAN_RX, '') + "\n"
    write_snippet block, source, snippet_path
    snippet_path
  end

  ##
  # Copies an override snippet from the filesystem into the snippets directory.
  def copy_override_snippet(block, source, uri)
    logger.info message_with_context "copying snippet #{source}",
      source_location: block.source_location
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

  ##
  # Writes a snippet extracted from the asciidoc file into the
  # snippets directory.
  def write_snippet(block, snippet, uri)
    logger.info message_with_context "writing snippet #{uri}",
      source_location: block.source_location
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
