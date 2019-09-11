# frozen_string_literal: true

require 'asciidoctor/extensions'
require 'csv'
require 'digest/murmurhash'
require_relative '../log_util'
require_relative '../scaffold'
require_relative 'listing'
require_relative 'lookup'
require_relative 'report'
require_relative 'summary'

module AlternativeLanguageLookup
  ##
  # TreeProcessor extension find alternative languages for snippets.
  class AlternativeLanguageLookup < TreeProcessorScaffold
    include LogUtil

    def process(document)
      lookups_string = document.attr 'alternative_language_lookups'
      return unless lookups_string

      if lookups_string.is_a? String
        document.attributes['alternative_language_lookups'] =
          parse_lookups lookups_string
      end

      summary = setup_summary document
      handle_report(document) { super }
      summary&.save
    end

    def parse_lookups(lookups_string)
      lookups = {}
      CSV.parse lookups_string do |source_lang, alternative_lang, dir|
        lookup = Lookup.new(source_lang, alternative_lang, dir)
        next unless lookup.valid
        next if duplicate_lookup? lookups, lookup

        lookups[source_lang] ||= []
        lookups[source_lang] << lookup
      end
      lookups
    end

    def duplicate_lookup?(lookups, lookup)
      alts = lookups[lookup.source_lang]&.map(&:alternative_lang)
      return false unless alts&.include? lookup.alternative_lang

      error message: <<~LOG.strip
        invalid alternative_language_lookups, duplicate alternative_lang [#{lookup.alternative_lang}]
      LOG
      true
    end

    def setup_summary(document)
      summary_path = document.attr 'alternative_language_summary'
      return unless summary_path.is_a? String

      lookups = document.attr 'alternative_language_lookups'
      summary = Summary.new summary_path, lookups
      document.attributes['alternative_language_summary'] = summary
      summary
    end

    def handle_report(document)
      report_path = document.attr 'alternative_language_report'
      if report_path&.is_a? String
        Report.open report_path do |report|
          document.attributes['alternative_language_report'] = report
          yield
        end
      else
        yield
      end
    end

    def process_block(block)
      return unless block.context == :listing && block.style == 'source'

      Listing.new(block).process
    end
  end
end
