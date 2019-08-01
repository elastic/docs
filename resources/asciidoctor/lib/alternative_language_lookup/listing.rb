# frozen_string_literal: true

require_relative 'alternative'

module AlternativeLanguageLookup
  ##
  # Information about a listing.
  class Listing
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
        next unless (found = find_alternative a[:dir])

        alternative = Alternative.new(self, a[:lang], a[:dir], found).block
        next unless alternative

        insert alternative
        found_langs << a[:lang]
      end
      report = document.attr 'alternative_language_report'
      report&.report self, found_langs
      return if found_langs.empty?

      has_roles = found_langs.map { |lang| "has-#{lang}" }.join ' '
      parent.reindex_sections
      @block.attributes['role'] = "default #{has_roles}"
      return unless @colist

      @colist.attributes['role'] = "default #{has_roles} lang-#{@lang}"
    end

    def find_alternative(dir)
      basename = "#{@digest}.adoc"
      return basename if File.exist? File.join(dir, basename)

      basename = "#{@digest}.asciidoc"
      return basename if File.exist? File.join(dir, basename)
    end

    def insert(alternative)
      unless @next_index
        # Find the right spot in the parent's blocks to add any alternatives:
        # right after this block's callouts if it has any, otherwise just after
        # this block.
        @next_index = parent.blocks.find_index(@block) + 1
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
