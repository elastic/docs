# frozen_string_literal: true

require 'fileutils'
require_relative 'alternative_validation'

module AlternativeLanguageLookup
  ##
  # Finds and loads alternative examples in alternative languages.
  class AlternativeFinder
    include AlternativeValidation

    def initialize(block, source_lang, alternative, digest, counter)
      @block = block
      @source_lang = source_lang
      @alternative = alternative
      @digest = digest
      @counter = counter
    end

    def find
      @basename = "#{@digest}.adoc"
      if File.exist? File.join(@alternative[:dir], @basename)
        build_alternative
      else
        @basename = "#{@digest}.asciidoc"
        if File.exist? File.join(@alternative[:dir], @basename)
          build_alternative
        else
          report_missing
          nil
        end
      end
    end

    def build_alternative
      # Parse the included portion as asciidoc but not as a "child" document
      # because that is for parsing text we've already parsed once. This is
      # text that we're detecting very late in the process.
      @child = Asciidoctor::Document.new(
        "include::#{@alternative[:dir]}/#{@basename}[]",
        attributes: @block.document.attributes.dup,
        safe: @block.document.safe,
        backend: @block.document.backend,
        doctype: Asciidoctor::DEFAULT_DOCTYPE,
        sourcemap: @block.document.sourcemap,
        base_dir: @block.document.base_dir,
        to_dir: @block.document.options[:to_dir]
      )
      @child.parse
      return unless validate_child

      munge_child
      Asciidoctor::Block.new(@block.parent, :pass, source: @child.convert)
    end

    ##
    # Modify the parsed child before converting it so it'll "fit" in the parent.
    def munge_child
      @source.attributes['role'] = 'alternative'
      # Munge the callouts so they don't collide with the parent doc
      @source.document.callouts.current_list.each do |co|
        co[:id] = munge_coid co[:id]
      end
      return unless @colist

      @colist.attributes['role'] = "alternative lang-#{@alternative[:lang]}"
      munge_list_coids
    end

    ##
    # Munge the link targets so they link properly to the munged ids in the
    # alternate example
    def munge_list_coids
      @colist.items.each do |item|
        coids = item.attr 'coids'
        next unless coids

        newcoids = []
        coids.split(' ').each do |coid|
          newcoids << munge_coid(coid)
        end
        item.attributes['coids'] = newcoids.join ' '
      end
    end

    def munge_coid(coid)
      "#{@alternative[:lang]}-#{@counter}-#{coid}"
    end

    def report_missing
      return unless (report_dir = @block.attr 'alternative_language_report_dir')

      dir = File.join report_dir, @source_lang
      FileUtils.mkdir_p dir
      file = File.join dir, @alternative[:lang]
      File.open file, 'a' do |f|
        f.puts <<~TXT
          * #{@digest}.adoc: #{@block.source_location}
        TXT
      end
    end
  end
end
