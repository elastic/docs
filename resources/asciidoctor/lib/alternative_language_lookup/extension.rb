# frozen_string_literal: true

require 'csv'
require 'digest/murmurhash'
require_relative '../scaffold'
require_relative 'alternative_finder'

module AlternativeLanguageLookup
  ##
  # TreeProcessor extension find alternative languages for snippets.
  class AlternativeLanguageLookup < TreeProcessorScaffold
    include Asciidoctor::Logging

    def process(document)
      lookups_string = document.attr 'alternative_language_lookups'
      return unless lookups_string
      return unless lookups_string.is_a? String

      lookups = parse_lookups lookups_string
      document.attributes['alternative_language_lookups'] = lookups
      document.attributes['alternative_language_counter'] = 0
      super
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

      source_lang = block.attr 'language'
      lookups = block.document.attr 'alternative_language_lookups'
      alternatives = lookups[source_lang]
      process_listing block, source_lang, alternatives if alternatives
    end

    def process_listing(block, source_lang, alternatives)
      # Find the right spot in the parent's blocks to add any alternatives:
      # right after this block's callouts if it has any, otherwise just after
      # this block.
      next_index = block.parent.blocks.find_index(block) + 1
      if (block_colist = block.parent.blocks[next_index])&.context == :colist
        next_index += 1
      else
        block_colist = nil
      end
      alternative_langs = []

      digest = Digest::MurmurHash3_x64_128.hexdigest block.lines.join "\n"
      counter = block.document.attr 'alternative_language_counter'
      alternatives.each do |alternative|
        finder = AlternativeFinder.new(
          block, source_lang, alternative, digest, counter
        )
        next unless (found = finder.find)

        block.parent.blocks.insert next_index, found
        next_index += 1
        counter += 1
        alternative_langs << alternative[:lang]
      end
      return if alternative_langs.empty?

      block.document.attributes['alternative_language_counter'] = counter
      has_roles = alternative_langs.map { |lang| "has-#{lang}" }.join ' '
      block.parent.reindex_sections
      block.attributes['role'] = "default #{has_roles}"
      return unless block_colist

      block_colist.attributes['role'] =
        "default #{has_roles} lang-#{source_lang}"
    end

    def error(message)
      logger.error message_with_context(message)
    end
  end
end
