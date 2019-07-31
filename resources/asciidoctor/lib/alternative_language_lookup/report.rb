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

    def report(listing, source_lang, alternatives, found_langs)
      lang_header = alternatives.map { |a| "| #{a[:lang]}" }.join ' '
      @file.puts <<~ASCIIDOC
        === #{listing.source_location}: #{listing.digest}
        [source,#{source_lang}]
        ----
        #{listing.source.gsub(/<([^>])>/, '\\<\1>')}
        ----
        |===
        #{lang_header}

        #{lang_line alternatives, found_langs}
        |===
      ASCIIDOC
    end

    def lang_line(alternatives, found_langs)
      alternatives
        .map { |a| found_langs.include?(a[:lang]) ? '| &check;' : '| &cross;' }
        .join ' '
    end
  end
end
