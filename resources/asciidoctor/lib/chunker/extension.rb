# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'
require_relative 'breadcrumbs'
require_relative 'extra_docinfo'
require_relative 'find_related'
require_relative 'nav'

##
# HTML5 converter that chunks like docbook.
module Chunker
  def self.activate(registry)
    doc = registry.document
    return unless doc.attr 'outdir'
    return unless (chunk_level = doc.attr 'chunk_level')

    doc.extend Chunker::ExtraDocinfo
    return if doc.attr 'subdoc'

    doc.attributes['toclevels'] ||= doc.attributes['chunk_level']

    DelegatingConverter.setup(registry.document) do |d|
      Converter.new d, chunk_level.to_i
    end
  end

  ##
  # A Converter implementation that chunks like docbook.
  class Converter < DelegatingConverter
    include Chunker::Breadcrumbs
    include Chunker::FindRelated

    def initialize(delegate, chunk_level)
      super(delegate)
      @chunk_level = chunk_level
    end

    def convert_document(doc)
      unless doc.attr 'home'
        title = doc.doctitle partition: true
        doc.attributes['home'] = title.main.strip
      end
      doc.attributes['next_section'] = find_next_in doc, 0
      nav = Nav.new doc
      doc.blocks.insert 0, nav.header
      doc.blocks.append nav.footer
      yield
    end

    def convert_outline(node, opts = {})
      # Fix links in the toc
      toclevels = opts[:toclevels] || node.document.attributes['toclevels'].to_i
      outline = yield
      cleanup_outline outline, node, toclevels
      outline
    end

    def convert_section(section)
      doc = section.document
      return yield unless section.level <= @chunk_level

      html = form_section_into_page doc, section, yield
      write doc, "#{section.id}.html", html
      ''
    end

    def convert_inline_anchor(node)
      correct_xref node if node.type == :xref
      yield
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
      subdoc << generate_breadcrumbs(doc, section)
      nav = Nav.new subdoc
      subdoc << nav.header
      subdoc << Asciidoctor::Block.new(subdoc, :pass, source: html)
      subdoc << nav.footer
      subdoc.convert
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
      attrs['doctitle'] = "#{section.title} | #{maintitle.main}"
      # Asciidoctor defaults these attribute to empty string if they aren't
      # specified and setting them to `nil` clears them. Since we want to
      # preserve the configuration from the parent into the child, we clear
      # explicitly them if they aren't found in the parent. If we didn't then
      # they'd default to fale.
      attrs['stylesheet'] = nil unless attrs['stylesheet']
      attrs['icons'] = nil unless attrs['icons']
      attrs['subdoc'] = true # Mark the subdoc so we don't try and chunk it
      attrs['noheader'] = true
      attrs.merge! find_related(section)
      attrs
    end

    def write(doc, file, html)
      dir = doc.attr 'outdir'
      path = File.join dir, file
      File.open path, 'w:UTF-8' do |f|
        f.write html
      end
      file
    end

    def cleanup_outline(outline, node, toclevels)
      node.sections.each do |section|
        outline.gsub!(%(href="##{section.id}"), %(href="#{section.id}.html")) ||
          raise("Couldn't fix section link for #{section.id} in #{outline}")
        cleanup_outline outline, section, toclevels if section.level < toclevels
      end
    end
  end
end
