# frozen_string_literal: true

require 'pathname'
require_relative '../scaffold.rb'

##
# TreeProcessor extension to automatically add "Edit Me" links to appropriate
# spots in the documentation.
#
class EditMe < TreeProcessorScaffold
  include Asciidoctor::Logging

  def process(document)
    logger.error("sourcemap is required") unless document.sourcemap
    super if document.attributes['edit_url']
  end

  def process_block(block)
    return unless %i[preamble section floating_title].include? block.context

    def block.title
      path = source_path
      url = @document.attributes['edit_url']
      url += '/' unless url.end_with?('/')
      repo_root = @document.attributes['repo_root']
      if repo_root
        repo_root = Pathname.new repo_root
        base_dir = Pathname.new @document.base_dir
        url += "#{base_dir.relative_path_from(repo_root)}/"
      end
      url += path
      "#{super}<ulink role=\"edit_me\" url=\"#{url}\">Edit me</ulink>"
    end
    if block.context == :preamble
      def block.source_path
        document.source_location.path
      end
    else
      def block.source_path
        source_location.path
      end
    end
  end
end
