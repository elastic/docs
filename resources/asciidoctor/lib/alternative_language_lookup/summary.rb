# frozen_string_literal: true

require 'json'

module AlternativeLanguageLookup
  ##
  # Summary of the alternative language listings included to be processed by
  # other tools.
  class Summary
    def initialize(path, lookups)
      @path = path
      @data = {}
      lookups.each do |source_lang, lang_lookups|
        @data[source_lang] = sdata = { total: 0, alternatives: {} }
        lang_lookups.each do |lookup|
          sdata[:alternatives][lookup[:lang]] = { found: 0 }
        end
      end
    end

    def on_listing(listing, found_langs)
      sdata = @data[listing.lang]
      sdata[:total] += 1
      adata = sdata[:alternatives]
      found_langs.each { |alt| adata[alt][:found] += 1 }
    end

    def save
      File.open @path, 'w:UTF-8' do |f|
        f.write JSON.pretty_generate(@data)
      end
    end
  end
end
