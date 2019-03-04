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
    logger.error("sourcemap is required") unless document.sourcemap
    edit_urls_string = document.attributes['edit_urls']
    return unless edit_urls_string

    edit_urls = []
    CSV.parse edit_urls_string do |toplevel, url|
      unless toplevel
        logger.error message_with_context "invalid edit_urls, no toplevel"
        next
      end
      unless url
        logger.error message_with_context "invalid edit_urls, no url"
        next
      end
      url = url[0..-2] if url.end_with? '/'
      edit_urls << { toplevel: toplevel, url: url }
    end
    document.attributes['edit_urls'] = edit_urls
    super
  end

  def process_block(block)
    return unless %i[preamble section floating_title].include? block.context

    def block.title
      # || '<stdin>' allows us to not blow up when translating strings that
      # aren't associated with any particular file. '<stdin>' is asciidoctor's
      # standard name for such strings.
      path = source_path || '<stdin>'

      edit_urls = @document.attributes['edit_urls']
      edit_url = edit_urls.find { |e| path.start_with? e[:toplevel] }
      unless edit_url
        logger.warn message_with_context "couldn't find edit url for #{path}", :source_location => source_location
        return super
      end
      url = edit_url[:url]
      url += path[edit_url[:toplevel].length..-1]
      "#{super}<ulink role=\"edit_me\" url=\"#{url}\">Edit me</ulink>"
    end
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
end
