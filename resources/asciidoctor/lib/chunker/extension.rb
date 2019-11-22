# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'

##
# HTML5 converter that chunks like docbook.
module Chunker
  def self.activate(registry)
    return unless registry.document.attr 'outdir'
    return unless (chunk_level = registry.document.attr 'chunk_level')

    if chunk_level.is_a? String
      registry.document.attributes['chunk_level'] = chunk_level.to_i
    end

    DelegatingConverter.setup(registry.document) { |d| Converter.new d }
  end

  ##
  # A Converter implementation that chunks like docbook.
  class Converter < DelegatingConverter
    def initialize(delegate)
      super(delegate)
    end

    def convert_section(node)
      doc = node.document
      chunk_level = doc.attr 'chunk_level'
      return yield unless node.level == chunk_level

      html = form_section_into_page doc, node.title, yield
      target = write doc, node.id, html
      link_opts = { type: :link, target: target }
      doc.register :links, target
      link = Asciidoctor::Inline.new node.parent, :anchor, node.title, link_opts
      %(<li><span class="chapter">#{link.convert}</span></li>)
    end

    def form_section_into_page(doc, title, html)
      # We don't use asciidoctor's "parent" documents here because they don't
      # seem to buy us much and they are an "internal" detail.
      subdoc = Asciidoctor::Document.new [], subdoc_opts(doc)
      subdoc << Asciidoctor::Block.new(subdoc, :pass, source: html)
      maintitle = doc.doctitle partition: true
      subdoc.attributes['title'] = "#{title} | #{maintitle.main}"
      subdoc.convert
    end

    def subdoc_opts(doc)
      {
        attributes: subdoc_attrs(doc),
        safe: doc.safe,
        backend: doc.backend,
        sourcemap: doc.sourcemap,
        base_dir: doc.base_dir,
        to_dir: doc.options[:to_dir],
        standalone: true,
      }
    end

    def subdoc_attrs(doc)
      attrs = doc.attributes.dup
      # Asciidoctor defaults these attribute to empty string if they aren't
      # specified and setting them to `nil` clears them. Since we want to
      # preserve the configuration from the parent into the child, we clear
      # explicitly them if they aren't found in the parent. If we didn't then
      # they'd default to fale.
      attrs['stylesheet'] = nil unless attrs['stylesheet']
      attrs['icons'] = nil unless attrs['icons']
      attrs
    end

    def write(doc, target, html)
      dir = doc.attr 'outdir'
      file = "#{target}.html"
      path = File.join dir, file
      File.open path, 'w:UTF-8' do |f|
        f.write html
      end
      file
    end
  end
end
