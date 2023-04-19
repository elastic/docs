# frozen_string_literal: true

require_relative 'link'

module Chunker
  ##
  # Generate the navigation header and footer.
  class Nav
    include Link

    attr_reader :header, :footer

    def initialize(doc)
      body = nav_body doc
      @header = Asciidoctor::Block.new(doc, :pass, source: <<~HTML)
        <div class="navheader">
        
        </div>
      HTML
      @footer = Asciidoctor::Block.new(doc, :pass, source: <<~HTML)
        <div class="navfooter">
        
        </div>
      HTML
    end

    private

    def nav_body(doc)
      nav = [
        %(<span class="prev">),
        nav_link(doc.attr('prev_section'), '« ', ''),
        %(</span>),
        %(<span class="next">),
        nav_link(doc.attr('next_section'), '', ' »'),
        %(</span>),
      ]
      nav.compact.join "\n"
    end

    def nav_link(section, lmarker, rmarker)
      return unless section
      # section could be the document itself which shouldn't render.
      return unless section.context == :section

      %(<a #{link_href section}>#{lmarker}#{link_text section}#{rmarker}</a>)
    end
  end
end
