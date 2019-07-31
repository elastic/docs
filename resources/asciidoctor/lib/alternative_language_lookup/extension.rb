# frozen_string_literal: true

require 'csv'
require 'digest/murmurhash'
require_relative '../scaffold'
require_relative 'loaded_alternative'
require_relative 'listing'
require_relative 'report'

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

      report_path = document.attr 'alternative_language_report'
      if report_path&.is_a? String
        Report.open report_path do |report|
          # TODO: It'd be cleaner if scaffold took a block
          document.attributes['alternative_language_report'] = report
          super
        end
      else
        super
      end
    end

    def parse_lookups(lookups_string)
      lookups = {}
      CSV.parse lookups_string do |source_lang, alternative_lang, dir|
        unless source_lang
          error 'invalid alternative_language_lookups, no source_lang'
          next
        end
        unless alternative_lang
          error 'invalid alternative_language_lookups, no alternative_lang'
          next
        end
        unless Dir.exist? dir
          error "invalid alternative_language_lookups, [#{dir}] doesn't exist"
          next
        end
        if lookups[source_lang]
          if lookups[source_lang].index { |a| a[:lang] == alternative_lang }
            error <<~LOG.strip
              invalid alternative_language_lookups, duplicate alternative_lang [#{alternative_lang}]
            LOG
          end
        else
          lookups[source_lang] = []
        end
        lookups[source_lang] << { lang: alternative_lang, dir: dir }
      end
      lookups
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
