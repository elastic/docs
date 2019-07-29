# frozen_string_literal: true

require 'csv'
require 'digest/murmurhash'
require 'fileutils'
require_relative '../scaffold'

##
# TreeProcessor extension find alternative languages for snippets.
#
class AlternativeLanguageLookup < TreeProcessorScaffold
  include Asciidoctor::Logging

  def process(document)
    lookups_string = document.attr 'alternative_language_lookups'
    return unless lookups_string
    return unless lookups_string.is_a? String

    lookups = parse_lookups lookups_string
    document.attributes['alternative_language_lookups'] = lookups
    super
  end

  def parse_lookups(lookups_string)
    lookups = {}
    CSV.parse lookups_string do |source_lang, alternative_lang, dir|
      unless source_lang
        error('invalid alternative_language_lookups, no source_lang')
        next
      end
      unless alternative_lang
        error('invalid alternative_language_lookups, no alternative_lang')
        next
      end
      unless Dir.exist? dir
        error("invalid alternative_language_lookups, [#{dir}] doesn't exist")
        next
      end
      lookups[source_lang] = [] unless lookups[source_lang]
      lookups[source_lang] << { lang: alternative_lang, dir: dir }
    end
    lookups
  end

  def process_block(block)
    return unless block.context == :listing && block.style == 'source'

    source_lang = block.attr 'language'
    lookups = block.document.attr 'alternative_language_lookups'
    alternatives = lookups[source_lang]
    process_listing block, source_lang, alternatives if alternatives
  end

  def process_listing(block, source_lang, alternatives)
    start_index = block.parent.blocks.find_index(block) + 1
    next_index = start_index
    digest = Digest::MurmurHash3_x64_128.hexdigest block.lines.join "\n"
    alternatives.each do |alternative|
      dir = alternative[:dir]
      basename = "#{digest}.adoc"
      unless File.exist? File.join(dir, basename)
        basename = "#{digest}.asciidoc"
        unless File.exist? File.join(dir, basename)
          report_missing block, source_lang, alternative, digest
          next
        end
      end

      new_script = build_alternative block, alternative, dir, basename
      block.attributes['role'] = 'default'
      block.parent.blocks.insert next_index, new_script
      next_index += 1
    end
    block.parent.reindex_sections unless next_index == start_index
  end

  def build_alternative(block, alternative, dir, basename)
    # Parse the included portion as asciidoc but not as a "child" document
    # because that is for parsing text we've already parsed once. This is
    # text that we're detecting very late in the process.
    source = <<~ASCIIDOC
      [source,#{alternative[:lang]}]
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
    new_script.attributes['role'] = 'alternative'
    new_script
  end

  def report_missing(block, source_lang, alternative, digest)
    return unless (report_dir = block.attr 'alternative_language_report_dir')

    dir = File.join report_dir, source_lang
    FileUtils.mkdir_p dir
    file = File.join dir, alternative[:lang]
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
