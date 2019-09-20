# frozen_string_literal: true

require 'json'

module AlternativeLanguageLookup
  ##
  # Reports on the result of processing a lookup.
  class Report
    def self.open(path)
      File.open path, 'w' do |f|
        f.print '['
        yield Report.new f
        f.print "]\n"
      end
    end

    def initialize(file)
      @file = file
      @first = true
    end

    def report(listing, found_langs)
      if @first
        @first = false
      else
        @file.print ','
      end
      @file.print "\n"
      @file.print json(listing, found_langs)
    end

    def json(listing, found_langs)
      JSON.generate(
        source_location: {
          file: listing.source_location.path,
          line: listing.source_location.lineno,
        },
        digest: listing.digest,
        lang: listing.lang,
        found: found_langs,
        source: listing.source
      )
    end
  end
end
