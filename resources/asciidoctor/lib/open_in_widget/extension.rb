# frozen_string_literal: true

require 'fileutils'

require_relative '../migration_log'
require_relative '../log_util'
require_relative '../scaffold'

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
  include LogUtil
  include MigrationLog

  CALLOUT_SCAN_RX = / ?#{Asciidoctor::CalloutScanRx}/

  def process_block(block)
    return unless block.context == :listing && block.style == 'source'

    lang = block.attr 'language'
    return unless %w[console sense kibana].include? lang

    snippet_path = snippet_path block, lang, block.attr('snippet')

    block.set_attr(
      'snippet_link', "<ulink type=\"snippet\" url=\"#{snippet_path}\"/>"
    )
    block.document.register :links, snippet_path

    def block.content
      "#{@attributes['snippet_link']}#{super}"
    end
  end

  def snippet_path(block, lang, snippet)
    return handle_override_snippet block, snippet if snippet

    handle_implicit_snippet block, lang
  end

  ##
  # Copy explicitly configured snippets to the right path so kibana can pick
  # them up and warn the user that they are lame.
  def handle_override_snippet(block, snippet)
    snippet_path = "snippets/#{snippet}"
    normalized = block.normalize_system_path(
      snippet_path, block.document.base_dir
    )
    if File.readable? normalized
      copy_override_snippet block, normalized, snippet_path
      migration_warn block, block.source_location, 'override-snippet',
                     'reading snippets from a path makes the book harder ' \
                     'to read'
    else
      error block: block, message: "can't read snippet from #{normalized}"
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
    info block: block, message: "copying snippet #{source}"
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
    info block: block, message: "writing snippet #{uri}"
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
