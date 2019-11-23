# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter'

##
# HTML5 converter that chunks like docbook.
module Chunker
  def self.activate(registry)
    doc = registry.document
    return unless doc.attr 'outdir'
    return unless (chunk_level = doc.attr 'chunk_level')

    doc.attributes['chunk_level'] = chunk_level.to_i if chunk_level.is_a? String

    doc.attributes['toclevels'] ||= doc.attributes['chunk_level']

    DelegatingConverter.setup(registry.document) { |d| Converter.new d }
  end

  ##
  # A Converter implementation that chunks like docbook.
  class Converter < DelegatingConverter
    def convert_document(doc)
      def doc.docinfo(location = :head, suffix = nil)
        info = super
        return info unless location == :head
  
        info + <<~HTML
          <link rel="home" href="index.html" title="#{attr 'home'}"/>
        HTML
      end
      unless doc.attr 'home'
        title = doc.doctitle partition: true
        doc.attributes['home'] = title.main
      end
      yield
    end

    def convert_section(node)
      doc = node.document
      chunk_level = doc.attr 'chunk_level'
      return yield unless node.level <= chunk_level

      html = form_section_into_page doc, node.title, yield
      write doc, "#{node.id}.html", html
      ''
    end

    def convert_outline(node, opts = {})
      # Fix links in the toc
      toclevels = opts[:toclevels] || node.document.attributes['toclevels'].to_i
      outline = yield
      cleanup_outline outline, node, toclevels
      outline
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
