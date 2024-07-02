# frozen_string_literal: true

require 'asciidoctor/extensions'
require 'csv'
require_relative '../delegating_converter'
require_relative '../log_util'

##
# Automatically adds "Edit Me" links to appropriate spots in the documentation.
module EditMe
  extend LogUtil

  def self.activate(registry)
    error message: 'sourcemap is required' unless registry.document.sourcemap
    return unless configure registry.document

    DelegatingConverter.setup(registry.document) do |doc|
      Converter.new doc
    end
  end

  def self.configure(document)
    edit_urls_string = document.attributes['edit_urls']
    return unless edit_urls_string

    if edit_urls_string.is_a? String
      document.attributes['edit_urls'] = parse_edit_urls edit_urls_string
      return unless document.attributes['edit_urls']
    end

    true
  end

  def self.parse_edit_urls(edit_urls_string)
    edit_urls = []
    CSV.parse edit_urls_string do |toplevel, url|
      handle_link edit_urls, toplevel, url
    end
    # Prefer the longest matching edit url
    edit_urls.sort_by { |e| [-e[:toplevel].length, e[:toplevel]] }
  end

  def self.handle_link(edit_urls, toplevel, url)
    unless toplevel
      error message: 'invalid edit_urls, no toplevel'
      return
    end
    unless url
      error message: 'invalid edit_urls, no url'
      return
    end
    url = url[0..-2] if url.end_with? '/'
    edit_urls << { toplevel: toplevel, url: url }
  end

  ##
  # Converter implementation that decorates titles with edit me links.
  class Converter < DelegatingConverter
    include LogUtil

    RESPECT_OVERRIDES = 'respect_edit_url_overrides'

    def convert_section(block)
      block.attributes['edit_me_link'] = link_for block
      yield
    end

    def convert_floating_title(block)
      block.attributes['edit_me_link'] = link_for block
      yield
    end

    def link_for(block)
      url = edit_url block
      return '' unless url

      if block.document.attr 'private_edit_urls'
        css_classes = 'edit_me edit_me_private'
        title = 'Editing on GitHub is available to Elastic'
      else
        css_classes = 'edit_me'
        title = 'Edit this page on GitHub'
      end

      <<~HTML.strip
        <a class="#{css_classes}" rel="nofollow" title="#{title}" href="#{url}"></a>
      HTML
    end

    def edit_url(block)
      return edit_url_by_path block unless block.document.attr RESPECT_OVERRIDES

      url = block.document.attr 'edit_url'
      return false if url == ''
      return url if url

      edit_url_by_path block
    end

    def edit_url_by_path(block)
      # source_location.path doesn't work for relative includes outside of
      # the base_dir which we use when we build books from many repos.
      # || '<stdin>' allows us to not blow up when translating strings that
      # aren't associated with any particular file. '<stdin>' is asciidoctor's
      # standard name for such strings.
      path = block.source_location&.file || '<stdin>'

      edit_urls = block.document.attr 'edit_urls'
      entry = edit_urls.find { |e| path.start_with? e[:toplevel] }
      return url_for_path path, entry if entry

      warn block: block, message: <<~WARN.strip
        couldn't find edit url for #{path}
      WARN
      false
    end

    def url_for_path(path, entry)
      url = entry[:url]
      if url == '<disable>'
        false
      else
        url + path[entry[:toplevel].length..-1]
      end
    end
  end
end
