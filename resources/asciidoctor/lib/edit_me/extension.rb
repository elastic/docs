require_relative '../scaffold.rb'

include Asciidoctor

##
# TreeProcessor extension to automatically add "Edit Me" links to appropriate
# spots in the documentation.
class EditMe < TreeProcessorScaffold
  include Logging

  def process document
    logger.error("sourcemap is required") unless document.sourcemap
    if document.attributes['edit_url']
      super
    end
  end

  def process_block block
    if [:preamble, :section, :floating_title].include? block.context
      def block.title
        url = @document.attributes['edit_url']
        url += '/' unless url.end_with?('/')
        url += source_path
        "#{super}<ulink role=\"edit_me\" url=\"#{url}\">Edit me</ulink>"
      end
      if :preamble == block.context
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
end
