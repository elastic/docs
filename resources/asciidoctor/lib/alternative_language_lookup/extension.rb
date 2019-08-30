# frozen_string_literal: true

require 'csv'
require 'digest/murmurhash'
require_relative '../scaffold'
require_relative 'listing'
require_relative 'report'
require_relative 'summary'

module AlternativeLanguageLookup
  ##
  # TreeProcessor extension find alternative languages for snippets.
  class AlternativeLanguageLookup < TreeProcessorScaffold
    include Asciidoctor::Logging

    def process(document)
      lookups_string = document.attr 'alternative_language_lookups'
      return unless lookups_string

      if lookups_string.is_a? String
        document.attributes['alternative_language_lookups'] =
          parse_lookups lookups_string
      end

      summary = nil
      summary_path = document.attr 'alternative_language_summary'
      if summary_path.is_a? String
        lookups = document.attr 'alternative_language_lookups'
        summary = Summary.new summary_path, lookups
        document.attributes['alternative_language_summary'] = summary
      end

      report_path = document.attr 'alternative_language_report'
      if report_path&.is_a? String
        Report.open report_path do |report|
          document.attributes['alternative_language_report'] = report
          super
        end
      else
        super
      end
      summary&.save
    end

    def parse_lookups(lookups_string)
      lookups = {}
      CSV.parse lookups_string do |source_lang, alternative_lang, dir|
        next unless validate_lookup source_lang, alternative_lang, dir

        if lookups[source_lang]
          if lookups[source_lang].index { |a| a[:lang] == alternative_lang }
            error <<~LOG.strip
              invalid alternative_language_lookups, duplicate alternative_lang [#{alternative_lang}]
            LOG
          end
        else
          lookups[source_lang] = []
        end
        lookups[source_lang] << {
          lang: alternative_lang,
          index: index_asciidoc([dir]),
        }
      end
      lookups
    end

    def validate_lookup(source_lang, alternative_lang, dir)
      valid = true
      unless source_lang
        error 'invalid alternative_language_lookups, no source_lang'
        valid = false
      end
      unless alternative_lang
        error 'invalid alternative_language_lookups, no alternative_lang'
        valid = false
      end
      unless Dir.exist? dir
        error "invalid alternative_language_lookups, [#{dir}] doesn't exist"
        valid = false
      end
      valid
    end

    ##
    # Build a hash indexing all `adoc` and `asciidoc` files in all directories
    # in `to_index` so that looking up files is fast later.
    def index_asciidoc(to_index)
      index = {}
      while (dir = to_index.shift)
        Dir.new(dir).each do |f|
          next if f == '.'
          next if f == '..'

          path = File.join dir, f
          if File.directory? path
            to_index << path
            next
          end

          extension = File.extname path
          next unless ['.asciidoc', '.adoc'].include? extension

          basename = File.basename path, extension
          index[basename] = { path: path }
        end
      end

      index
    end

    def process_block(block)
      return unless block.context == :listing && block.style == 'source'

      Listing.new(block).process
    end

    def error(message)
      logger.error message_with_context(message)
    end
  end
end
