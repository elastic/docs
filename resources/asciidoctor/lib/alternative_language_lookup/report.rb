# frozen_string_literal: true

module AlternativeLanguageLookup
  ##
  # Reports on the result of processing a lookup.
  class Report
    def self.open(path)
      File.open path, 'w' do |f|
        yield Report.new(f)
      end
    end

    def initialize(file)
      @file = file
      @file.puts <<~ASCIIDOC
        == Alternatives Report

      ASCIIDOC
    end

    def report(listing, found_langs)
      @file.puts <<~ASCIIDOC
        === #{listing.source_location}: #{listing.digest}
        [source,#{listing.lang}]
        ----
        #{listing.source.gsub(/<([^>])>/, '\\<\1>')}
        ----
        |===
        #{lang_header listing}

        #{lang_line listing, found_langs}
        |===
      ASCIIDOC
    end

    def lang_header(listing)
      listing.alternatives.map { |a| "| #{a[:lang]}" }.join ' '
    end

    def lang_line(listing, found_langs)
      listing
        .alternatives
        .map { |a| found_langs.include?(a[:lang]) ? '| &check;' : '| &cross;' }
        .join ' '
    end
  end
end
