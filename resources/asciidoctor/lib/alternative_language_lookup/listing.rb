# frozen_string_literal: true

module AlternativeLanguageLookup
  ##
  # Information about a listing.
  class Listing
    attr_reader :block
    attr_reader :source
    attr_reader :digest
    attr_reader :lang
    attr_reader :alternatives

    def initialize(block)
      @block = block
      @lang = block.attr 'language'
      lookups = block.document.attr 'alternative_language_lookups'
      @alternatives = lookups[@lang]
      return unless @alternatives

      # We don't need these unless there are alternatives
      @source = @block.source
      @digest = Digest::MurmurHash3_x64_128.hexdigest @source
    end

    def find_alternative(dir)
      basename = "#{@digest}.adoc"
      return basename if File.exist? File.join(dir, basename)

      basename = "#{@digest}.asciidoc"
      return basename if File.exist? File.join(dir, basename)
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
