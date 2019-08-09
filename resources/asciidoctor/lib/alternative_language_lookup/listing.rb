# frozen_string_literal: true

require_relative 'alternative'

module AlternativeLanguageLookup
  ##
  # Information about a listing in the original document.
  class Listing
    include Asciidoctor::Logging

    attr_reader :block
    attr_reader :lang
    attr_reader :alternatives
    attr_reader :source
    attr_reader :digest

    def initialize(block)
      @block = block
      @lang = block.attr 'language'
      lookups = block.document.attr 'alternative_language_lookups'
      @alternatives = lookups[@lang]
    end

    def process
      return unless @alternatives

      @source = @block.source
      @digest = Digest::MurmurHash3_x64_128.hexdigest @source
      @next_index = nil # We'll look it up when we need it

      found_langs = []

      @alternatives.each do |a|
        next unless (found = a[:index][@digest])

        # TODO: we can probably cache this. There are lots of dupes.
        alternative = Alternative.new document, a[:lang], found[:path]
        alternative_block = alternative.block @block
        next unless alternative_block

        insert alternative_block
        found_langs << a[:lang]
      end
      report = document.attr 'alternative_language_report'
      report&.report self, found_langs

      cleanup_original_after_add found_langs unless found_langs.empty?
    end

    def insert(alternative)
      unless @next_index
        # Find the right spot in the parent's blocks to add any alternatives:
        # right after this block's callouts if it has any, otherwise just after
        # this block.
        @next_index = parent.blocks.find_index(@block) + 1
        unless @next_index
          message = "Invalid document: parent doesn't include child!"
          logger.error(message_with_context(message, @block.source_location))
          # In grand Asciidoctor tradition we'll *try* to make some
          # output though
          @next_index = 0
        end
        if (colist = parent.blocks[@next_index])&.context == :colist
          @next_index += 1
          @colist = colist
        else
          @colist = nil
        end
      end

      parent.blocks.insert @next_index, alternative
      @next_index += 1
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

    def parent
      @block.parent
    end

    def document
      @block.document
    end

    def source_location
      @block.source_location
    end
  end
end
