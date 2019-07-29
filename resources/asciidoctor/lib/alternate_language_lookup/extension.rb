# frozen_string_literal: true

require 'csv'
require 'digest/murmurhash'
require 'fileutils'
require_relative '../scaffold'

##
# TreeProcessor extension to automatically add "Edit Me" links to appropriate
# spots in the documentation.
#
class AlternateLanguageLookup < TreeProcessorScaffold
  include Asciidoctor::Logging

  def process(document)
    lookups_string = document.attr 'alternate_language_lookups'
    return unless lookups_string
    return unless lookups_string.is_a? String

    lookups = parse_lookups lookups_string
    document.attributes['alternate_language_lookups'] = lookups
    super
  end

  def parse_lookups(lookups_string)
    lookups = {}
    CSV.parse lookups_string do |source_lang, alternate_lang, dir|
      unless source_lang
        error('invalid alternate_language_lookups, no source_lang')
        next
      end
      unless alternate_lang
        error('invalid alternate_language_lookups, no alternate_lang')
        next
      end
      unless Dir.exist? dir
        error("invalid alternate_language_lookups, [#{dir}] doesn't exist")
        next
      end
      lookups[source_lang] = [] unless lookups[source_lang]
      lookups[source_lang] << { lang: alternate_lang, dir: dir }
    end
    lookups
  end

  def process_block(block)
    return unless block.context == :listing && block.style == 'source'

    source_lang = block.attr 'language'
    lookups = block.document.attr 'alternate_language_lookups'
    alternates = lookups[source_lang]
    process_listing block, source_lang, alternates if alternates
  end

  def process_listing(block, source_lang, alternates)
    start_index = block.parent.blocks.find_index(block) + 1
    next_index = start_index
    digest = Digest::MurmurHash3_x64_128.hexdigest block.lines.join "\n"
    alternates.each do |alternate|
      dir = alternate[:dir]
      basename = "#{digest}.adoc"
      unless File.exist? File.join(dir, basename)
        basename = "#{digest}.asciidoc"
        unless File.exist? File.join(dir, basename)
          report_missing block, source_lang, alternate, digest
          next
        end
      end

      new_script = build_alternate block, alternate, dir, basename
      block.attributes['role'] = 'default'
      block.parent.blocks.insert next_index, new_script
      next_index += 1
    end
    block.parent.reindex_sections unless next_index == start_index
  end

  def build_alternate(block, alternate, dir, basename)
    # Parse the included portion as asciidoc but not as a "child" document
    # because that is for parsing text we've already parsed once. This is
    # text that we're detecting very late in the process.
    source = <<~ASCIIDOC
      [source,#{alternate[:lang]}]
      ----
      include::#{basename}[]
      ----
    ASCIIDOC
    child = Asciidoctor::Document.new(
      source,
      attributes: block.document.attributes.dup,
      safe: block.document.safe,
      backend: block.document.backend,
      doctype: Asciidoctor::DEFAULT_DOCTYPE,
      sourcemap: block.document.sourcemap,
      base_dir: dir,
      cursor: Asciidoctor::Reader::Cursor.new(basename, dir)
    )

    new_script = child.parse.blocks[0]
    new_script.parent = block.parent
    new_script.attributes['role'] = 'alternate'
    new_script
  end

  def report_missing(block, source_lang, alternate, digest)
    return unless (report_dir = block.attr 'alternate_language_report_dir')

    dir = File.join report_dir, source_lang
    FileUtils.mkdir_p dir
    file = File.join dir, alternate[:lang]
    File.open file, 'a' do |f|
      f.puts <<~TXT
        * #{digest}.adoc: #{block.source_location}
      TXT
    end
  end

  def error(message)
    logger.error message_with_context(message)
  end
end
