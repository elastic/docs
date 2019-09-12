# frozen_string_literal: true

require_relative 'alternative'
require_relative '../log_util'

module AlternativeLanguageLookup
  ##
  # Information about a listing in the original document.
  class Listing
    RESULT_SUFFIX = '-result'
    RESULT_SUFFIX_LENGTH = RESULT_SUFFIX.length

    include LogUtil

    attr_reader :block
    attr_reader :lang
    attr_reader :is_result
    attr_reader :alternatives

    def initialize(block)
      @block = block
      @lang = block.attr 'language'
      return unless @lang

      @is_result = @lang.end_with? RESULT_SUFFIX
      lookups = block.document.attr 'alternative_language_lookups'
      @alternatives = lookups[key_lang]
      @listing_index = nil # We'll look it up when we need it
      @colist_offset = 1
    end

    def process
      return unless alternatives

      found_langs = []

      alternatives.each do |lookup|
        add_alternative_if_present found_langs, lookup
      end
      report found_langs

      cleanup_original_after_add found_langs unless found_langs.empty?
    end

    def add_alternative_if_present(found_langs, lookup)
      return unless (found = lookup.index[digest])

      # TODO: we can probably cache this. There are lots of dupes.
      alt_lang = lookup.alternative_lang_for @is_result
      alternative = Alternative.new document, alt_lang, found[:path]
      alternative_listing = alternative.listing @block.parent
      return unless alternative_listing

      alternative_colist = alternative.colist @block.parent
      insert alternative_listing, alternative_colist
      found_langs << lookup.alternative_lang
    end

    def insert(alternative_listing, alternative_colist)
      find_listing unless @listing_index

      parent.blocks.insert @listing_index, alternative_listing
      @listing_index += 1
      return unless alternative_colist

      parent.blocks.insert @listing_index + @colist_offset, alternative_colist
      @colist_offset += 1
    end

    def find_listing
      # Find the right spot in the parent's blocks to add any alternatives:
      # right after this block's callouts if it has any, otherwise just after
      # this block.
      @listing_index = parent.blocks.find_index(@block)
      if @listing_index
        # While we're here check if there is a callout list.
        colist = parent.blocks[@listing_index + 1]
        @colist = colist&.context == :colist ? colist : nil
      else
        message = "Invalid document: parent doesn't include child!"
        error location: source_location, message: message
        # In grand Asciidoctor tradition we'll *try* to make some
        # output though
        @listing_index = 0
        @colist = nil
      end
    end

    def cleanup_original_after_add(found_langs)
      # We're obligated to reindex the sections inside parent because we've
      # chaged its blocks.
      parent.reindex_sections

      # Add some roles which will translate into classes to the original
      # listing block and the callout. We'll use these to hide the default
      # language when you pick an override language.
      has_roles = found_langs.map { |lang| "has-#{lang}" }.join ' '
      @block.attributes['role'] = "default #{has_roles}"
      return unless @colist

      @colist.attributes['role'] = "default #{has_roles} lang-#{@lang}"
    end

    def report(found_langs)
      report = document.attr 'alternative_language_report'
      report&.report self, found_langs
      summary = document.attr 'alternative_language_summary'
      summary&.on_listing self, found_langs
    end

    def parent
      @block.parent
    end

    def document
      @block.document
    end

    def source_location
      @block.source_location
    end

    def source
      @source ||= @block.source
    end

    def digest
      @digest ||= Digest::MurmurHash3_x64_128.hexdigest source
    end

    ##
    # `key_lang` normalises `lang` into the lookup key for alternatives.
    def key_lang
      if @is_result
        @lang[0, @lang.length - RESULT_SUFFIX_LENGTH]
      else
        @lang
      end
    end
  end
end
