# frozen_string_literal: true

require 'csv'
require_relative '../scaffold.rb'

##
# TreeProcessor extension to automatically add "Edit Me" links to appropriate
# spots in the documentation.
#
class EditMe < TreeProcessorScaffold
  include Asciidoctor::Logging

  def process(document)
    logger.error('sourcemap is required') unless document.sourcemap
    edit_urls_string = document.attributes['edit_urls']
    return unless edit_urls_string

    edit_urls = []
    CSV.parse edit_urls_string do |toplevel, url|
      unless toplevel
        logger.error message_with_context 'invalid edit_urls, no toplevel'
        next
      end
      unless url
        logger.error message_with_context 'invalid edit_urls, no url'
        next
      end
      url = url[0..-2] if url.end_with? '/'
      edit_urls << { toplevel: toplevel, url: url }
    end
    # Prefer the longest matching edit url
    edit_urls = edit_urls.sort_by { |e| [-e[:toplevel].length, e[:toplevel]] }
    document.attributes['edit_urls'] = edit_urls
    super
  end

  def process_block(block)
    return unless %i[preamble section floating_title].include? block.context

    block.extend WithEditLink
    if block.context == :preamble
      def block.source_path
        # source_location.path doesn't work for relative includes outside of
        # the base_dir which we use when we build books from many repos.
        document.source_location.file
      end
    else
      def block.source_path
        # source_location.path doesn't work for relative includes outside of
        # the base_dir which we use when we build books from many repos.
        source_location.file
      end
    end
  end

  ##
  # Extension to blocks that need an "edit me" link.
  module WithEditLink
    def title
      url = edit_url
      return super unless url

      "#{super}<ulink role=\"edit_me\" url=\"#{edit_url}\">Edit me</ulink>"
    end

    def edit_url
      if @document.attributes['respect_edit_url_overrides']
        url = @document.attributes['edit_url']
        return url if url
      end

      # || '<stdin>' allows us to not blow up when translating strings that
      # aren't associated with any particular file. '<stdin>' is asciidoctor's
      # standard name for such strings.
      path = source_path || '<stdin>'

      edit_urls = @document.attributes['edit_urls']
      entry = edit_urls.find { |e| path.start_with? e[:toplevel] }
      unless entry
        logger.warn(
          message_with_context(
            "couldn't find edit url for #{path}",
            source_location: source_location
          )
        )
        return false
      end

      url = entry[:url]
      return false if url == '<disable>'

      url + path[entry[:toplevel].length..-1]
    end
  end
end
