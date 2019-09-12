# frozen_string_literal: true

require_relative '../log_util'

module AlternativeLanguageLookup
  ##
  # Configuration about where to lookup snippets for a particular
  # alternative language.
  class Lookup
    include LogUtil

    attr_reader :source_lang
    attr_reader :alternative_lang
    attr_reader :index
    attr_reader :valid

    def initialize(source_lang, alternative_lang, dir)
      @source_lang = source_lang
      @alternative_lang = alternative_lang
      @dir = dir
      @valid = true
      validate_source_lang
      validate_alternative_lang
      validate_dir
      @index = build_index if @valid
    end

    ##
    # The alternative language, modified if this is a result.
    def alternative_lang_for(is_result)
      if is_result
        alternative_lang + '-result'
      else
        alternative_lang
      end
    end

    ##
    # Build a hash indexing all `adoc` and `asciidoc` files in all
    # subdirectories of @dir.
    def build_index
      to_index = [@dir]
      index = {}
      while (dir = to_index.shift)
        Dir.new(dir).each { |entry| index_entry to_index, index, dir, entry }
      end

      index
    end

    def index_entry(to_index, index, dir, entry)
      return if ['.', '..'].include? entry

      path = File.join dir, entry

      if File.directory? path
        to_index << path
      else
        extension = File.extname path
        return unless ['.asciidoc', '.adoc'].include? extension

        basename = File.basename path, extension
        index[basename] = { path: path }
      end
    end

    def validate_source_lang
      return if @source_lang

      error message: 'invalid alternative_language_lookups, no source_lang'
      @valid = false
    end

    def validate_alternative_lang
      return if @alternative_lang

      error message: 'invalid alternative_language_lookups, no alternative_lang'
      @valid = false
    end

    def validate_dir
      return if Dir.exist? @dir

      error message: <<~ERR.strip
        invalid alternative_language_lookups, [#{@dir}] doesn't exist
      ERR
      @valid = false
    end
  end
end
