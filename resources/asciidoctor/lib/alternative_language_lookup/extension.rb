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

  LAYOUT_DESCRIPTION = <<~LOG.freeze
    Alternative language must be a code block followed optionally by a callout list
  LOG

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
    # Find the right spot in the parent's blocks to add any alternatives: right
    # after this block's callouts if it has any, otherwise just after
    # this block.
    start_index = block.parent.blocks.find_index(block) + 1
    if (block_colist = block.parent.blocks[start_index])&.context == :colist
      start_index += 1
    else
      block_colist = nil
    end
    next_index = start_index

    digest = Digest::MurmurHash3_x64_128.hexdigest block.lines.join "\n"
    alternatives.each do |alternative|
      found = find_alternative(block, alternative, digest)
      if found
        block.parent.blocks.insert next_index, found
        next_index += 1
      end
    end
    unless next_index == start_index
      block.parent.reindex_sections
      block.attributes['role'] = 'default'
      block_colist.attributes['role'] = 'default' if block_colist
    end
  end

  def find_alternative(block, alternative, digest)
    basename = "#{digest}.adoc"
    if File.exist? File.join(alternative[:dir], basename)
      build_alternative block, alternative, digest, basename
    else
      basename = "#{digest}.asciidoc"
      if File.exist? File.join(alternative[:dir], basename)
        build_alternative block, alternative, digest, basename
      else
        report_missing block, source_lang, alternative, digest
      end
    end
  end

  def build_alternative(block, alternative, digest, basename)
    # Parse the included portion as asciidoc but not as a "child" document
    # because that is for parsing text we've already parsed once. This is
    # text that we're detecting very late in the process.
    next_index = block.parent.blocks.find_index(block) + 1

    source = <<~ASCIIDOC
      include::#{basename}[]
    ASCIIDOC
    child = Asciidoctor::Document.new(
      source,
      attributes: block.document.attributes.dup,
      safe: block.document.safe,
      backend: block.document.backend,
      doctype: Asciidoctor::DEFAULT_DOCTYPE,
      sourcemap: block.document.sourcemap,
      base_dir: alternative[:dir],
      to_dir: block.document.options[:to_dir]
    )
    if (child = prep_child(alternative, digest, child.parse))
      Asciidoctor::Block.new(block.parent, :pass, source: child.convert)
    else
      nil
    end
  end

  def prep_child(alternative, digest, child)
    ok = true
    unless [1, 2].include?(child.blocks.length)
      warn_child child.source_location, <<~LOG
        #{LAYOUT_DESCRIPTION} but was:
        #{child.blocks}
      LOG
      ok = false
    end
    unless (source = child.blocks[0]).context == :listing
      warn_child source.source_location, <<~LOG
        #{LAYOUT_DESCRIPTION} but the first block was a #{source.context}.
      LOG
      ok = false
    end
    unless (colist = child.blocks[1]).context == :colist
      warn_child colist.source_location, <<~LOG
        #{LAYOUT_DESCRIPTION} but the second block was a #{colist.context}.
      LOG
      ok = false
    end
    unless (lang = source.attr 'language') == alternative[:lang]
      warn_child source.source_location, <<~LOG
        Alternative language source must have lang=#{alternative[:lang]} but was #{lang}.
      LOG
      ok = false
    end
    if ok
      munge_child alternative, digest, source, colist
      child
    else
      nil
    end
  end

  def munge_child(alternative, digest, source, colist)
    source.attributes['role'] = 'alternative'
    colist.attributes['role'] = "alternative lang-#{alternative[:lang]}"
    # Munge the callouts so they don't collide with the parent doc
    source.document.callouts.current_list.each do |co|
      co[:id] = "#{alternative[:lang]}-#{digest}-#{co[:id]}"
    end
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

  def warn_child(location, message)
    logger.warn message_with_context message, source_location: location
  end
end
