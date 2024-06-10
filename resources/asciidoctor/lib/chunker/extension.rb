# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'
require_relative '../strip_tags'
require_relative 'breadcrumbs'
require_relative 'convert_outline'
require_relative 'extra_docinfo'
require_relative 'find_related'
require_relative 'footnotes'
require_relative 'nav'

##
# HTML5 converter that chunks like docbook.
module Chunker
  def self.activate(registry)
    doc = registry.document
    return unless doc.attr 'outdir'
    return unless (chunk_level = doc.attr 'chunk_level')

    doc.extend ExtraDocinfo
    return if doc.attr 'subdoc'

    doc.attributes['toclevels'] ||= doc.attributes['chunk_level']

    DelegatingConverter.setup(registry.document) do |d|
      Converter.new d, chunk_level.to_i
    end
  end

  ##
  # A Converter implementation that chunks like docbook.
  class Converter < DelegatingConverter
    include Breadcrumbs
    include ConvertOutline
    include FindRelated
    include Footnotes
    include StripTags

    def initialize(delegate, chunk_level)
      super(delegate)
      @chunk_level = chunk_level
    end

    def convert_document(doc)
      title = doc.doctitle partition: true
      doc.attributes['home'] = strip_tags(
        title.main.strip + doc.attr('title-extra', '')
      )
      doc.attributes['next_section'] = find_next_in doc, 0
      add_nav doc
      yield
    end

    def convert_section(section)
      doc = section.document
      return yield unless section.level <= @chunk_level

      html = form_section_into_page doc, section, yield
      # Replace the breadcrumbs placeholder with
      # the generated breadcrumbs
      if html =~ %r{<div id="breadcrumbs-go-here"></div>}
        html.gsub!(
          %r{<div id="breadcrumbs-go-here"></div>},
          generate_breadcrumbs(section)
        )
        # raise("Couldn't add breadcrumbs in #{html}")
      end
      write doc, "#{section.id}.html", html
      ''
    end

    def convert_inline_anchor(node)
      correct_xref node if node.type == :xref
      yield
    end

    def add_nav(doc)
      nav = Nav.new doc
      doc.blocks.insert 0, nav.header
      doc.blocks.append nav.footer
    end

    def correct_xref(node)
      refid = node.attributes['refid']
      return unless (ref = node.document.catalog[:refs][refid])

      page = page_containing ref
      node.target = "#{page.id}.html"
      node.target += "##{ref.id}" unless page == ref
    end

    def page_containing(node)
      page = node
      while page.context != :section || page.level > @chunk_level
        page = page.parent
      end
      page
    end

    def form_section_into_page(doc, section, html)
      # We don't use asciidoctor's "parent" documents here because they don't
      # seem to buy us much and they are an "internal" detail.
      subdoc = Asciidoctor::Document.new [], subdoc_opts(doc, section)
      add_subdoc_sections doc, subdoc, html
      subdoc.convert
    end

    def add_subdoc_sections(doc, subdoc, html)
      nav = Nav.new subdoc
      subdoc << nav.header
      subdoc << Asciidoctor::Block.new(subdoc, :pass, source: html)
      subdoc << footnotes(doc, subdoc) if doc.footnotes?
      subdoc << nav.footer
    end

    def subdoc_opts(doc, section)
      {
        attributes: subdoc_attrs(doc, section),
        safe: doc.safe,
        backend: doc.backend,
        sourcemap: doc.sourcemap,
        base_dir: doc.base_dir,
        to_dir: doc.options[:to_dir],
        standalone: true,
      }
    end

    def subdoc_attrs(doc, section)
      attrs = doc.attributes.dup
      maintitle = doc.doctitle partition: true
      # Rendered h1 heading
      attrs['doctitle'] = subdoc_doctitle section
      # Value of `title` in the `head`
      attrs['title'] = subdoc_title section, maintitle
      # Asciidoctor defaults these attribute to empty string if they aren't
      # specified and setting them to `nil` clears them. Since we want to
      # preserve the configuration from the parent into the child, we clear
      # explicitly them if they aren't found in the parent. If we didn't then
      # they'd default to fale.
      attrs['stylesheet'] = nil unless attrs['stylesheet']
      attrs['icons'] = nil unless attrs['icons']
      attrs['subdoc'] = true # Mark the subdoc so we don't try and chunk it
      attrs['title-separator'] = ''
      attrs['canonical-url'] = section.attributes['canonical-url']
      attrs.merge! find_related(section)
      attrs
    end

    # For the `h1` heading that appears on the rendered page,
    # use just the page title
    def subdoc_doctitle(section)
      strip_tags section.captioned_title.to_s
    end

    # For the `title` in the `head`, use the page title followed
    # by the site title ("Elastic")
    def subdoc_title(section, maintitle)
      strip_tags "#{section.captioned_title} | #{maintitle.main}"
    end

    def write(doc, file, html)
      dir = doc.attr 'outdir'
      path = File.join dir, file
      File.open path, 'w:UTF-8' do |f|
        f.write html
      end
      file
    end
  end
end
