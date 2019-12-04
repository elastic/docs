# frozen_string_literal: true

require 'fileutils'

require_relative '../delegating_converter'
require_relative '../migration_log'
require_relative '../log_util'

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
module OpenInWidget
  def self.activate(registry)
    DelegatingConverter.setup(registry.document) do |doc|
      Converter.new doc
    end
  end

  ##
  # Converter implementation that adds the "open in" links
  class Converter < DelegatingConverter
    include LogUtil
    include MigrationLog

    CALLOUT_SCAN_RX = / ?#{Asciidoctor::CalloutScanRx}/

    def convert_listing(node)
      return yield unless node.style == 'source'

      lang = node.attr 'language'
      return yield unless %w[console sense kibana ess ece].include? lang

      snippet_path = snippet_path node, lang, node.attr('snippet')
      convert_listing_with_widget node, lang, snippet_path, yield
    end

    def convert_listing_with_widget(node, lang, snippet_path, original)
      if node.document.basebackend? 'html'
        <<~HTML.strip
          #{original}
          <div class="#{lang}_widget" data-snippet="#{snippet_path}"></div>
        HTML
      else
        original.gsub(
          '</programlisting>',
          "<ulink type=\"snippet\" url=\"#{snippet_path}\"/></programlisting>"
        )
      end
    end

    def snippet_path(block, lang, snippet)
      return handle_override_snippet block, snippet if snippet

      handle_implicit_snippet block, lang
    end

    ##
    # Copy explicitly configured snippets to the right path so kibana can pick
    # them up when you click "open in console" and then warn the user that they
    # are lame.
    def handle_override_snippet(block, snippet)
      snippet_path = "snippets/#{snippet}"
      normalized = block.normalize_system_path snippet_path
      if File.readable? normalized
        copy_override_snippet block, normalized, snippet_path
        warn_override_snippet block
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
    # Copies an override snippet from the filesystem into the
    # snippets directory.
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

    def warn_override_snippet(block)
      migration_warn(
        block,
        block.source_location,
        'override-snippet',
        'reading snippets from a path makes the book harder to read'
      )
    end
  end
end
