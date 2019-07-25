# frozen_string_literal: true

require 'csv'
require 'digest/murmurhash'
require_relative '../scaffold'

##
# TreeProcessor extension to automatically add "Edit Me" links to appropriate
# spots in the documentation.
#
class AlternateLanguageLookup < TreeProcessorScaffold
  include Asciidoctor::Logging

  def process(document)
    lookups_string = document.attributes['alternate_language_lookups']
    return unless lookups_string

    lookups = {}
    CSV.parse lookups_string do |source_lang, alternate_lang, dir|
      unless source_lang
        logger.error(message_with_context(
          'invalid alternate_language_lookups, no source_lang'
        ))
        next
      end
      unless alternate_lang
        logger.error(message_with_context(
          'invalid alternate_language_lookups, no alternate_lang'
        ))
        next
      end
      unless alternate_lang
        logger.error(message_with_context(
          'invalid alternate_language_lookups, no alternate_lang'
        ))
        next
      end
      unless Dir.exist? dir
        logger.error(message_with_context(
          "invalid alternate_language_lookups, [#{dir}] doesn't exist"
        ))
        next
      end
      lookups[source_lang] = [] unless lookups[source_lang]
      lookups[source_lang] << { lang: alternate_lang, dir: dir }
    end
    document.attributes['alternate_language_lookups'] = lookups
    super
  end
  # Things to think about
  # * callouts!

  def process_block(block)
    return unless block.context == :listing && block.style == 'source'

    source_lang = block.attr 'language'
    lookups = block.document.attributes['alternate_language_lookups']
    return unless alternates = lookups[source_lang]

    digest = Digest::MurmurHash3_x64_128.hexdigest block.lines.join "\n"
    alternates.each do |alternate|
      dir = alternate[:dir]
      basename = "#{digest}.adoc"
      file = File.join dir, basename
      unless File.exist? file
        basename = "#{digest}.asciidoc"
        file = File.join dir, basename
        next unless File.exist? file
      end

      puts "asdf #{file}"
      cursor = Reader::Cursor.new basename, file
      reader = PreprocessorReader.new block.document, file.readlines, cursor, :normalize => true
      lines = read.read_lines
      puts "ASDFADF\n#{lines}asdf"
    end
  end
end
