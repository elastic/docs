# frozen_string_literal: true

require_relative 'alternative_validation'

module AlternativeLanguageLookup
  ##
  # Load alternative examples in alternative languages. This class
  # is "one shot" because it dirties it local variables as part of the find
  # process. Make one, call find, and throw it away.
  class LoadedAlternative
    include AlternativeValidation

    def initialize(listing, alternative, basename)
      @listing = listing
      @dir = alternative[:dir]
      @lang = alternative[:lang]
      @basename = basename
      @counter = listing.document.attr 'alternative_language_counter', 0
      @loaded = false
      load
      return unless validate_child

      munge_child
      @loaded = true
      listing.document.attributes['alternative_language_counter'] = @counter + 1
    end

    def block
      return unless @loaded

      Asciidoctor::Block.new @listing.parent, :pass, source: @child.convert
    end

    def load
      # Parse the included portion as asciidoc but not as a "child" document
      # because that is for parsing text we've already parsed once. This is
      # text that we're detecting very late in the process.
      @child = Asciidoctor::Document.new(
        "include::#{@dir}/#{@basename}[]",
        attributes: @listing.document.attributes.dup,
        safe: @listing.document.safe,
        backend: @listing.document.backend,
        doctype: Asciidoctor::DEFAULT_DOCTYPE,
        sourcemap: @listing.document.sourcemap,
        base_dir: @listing.document.base_dir,
        to_dir: @listing.document.options[:to_dir]
      )
      @child.parse
    end

    ##
    # Validate and prepare the child
    def validate_child
      unless [1, 2].include?(@child.blocks.length)
        warn_child @child.source_location, <<~LOG.strip
          #{LAYOUT_DESCRIPTION} but was:
          #{@child.blocks}
        LOG
        return false
      end

      @listing = @child.blocks[0]
      @colist = @child.blocks[1]
      check_listing & check_colist
    end

    ##
    # Modify the parsed child before converting it so it'll "fit" in the parent.
    def munge_child
      @listing.attributes['role'] = 'alternative'
      # Munge the callouts so they don't collide with the parent doc
      @listing.document.callouts.current_list.each do |co|
        co[:id] = munge_coid co[:id]
      end
      return unless @colist

      @colist.attributes['role'] = "alternative lang-#{@lang}"
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
      "A#{@counter}-#{coid}"
    end
  end
end
