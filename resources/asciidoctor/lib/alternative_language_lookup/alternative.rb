# frozen_string_literal: true

require_relative '../log_util'

module AlternativeLanguageLookup
  ##
  # Load alternative examples in alternative languages. Creating this class is
  # comparatively heavy because it parses the example. It'll also log warnings
  # if there are problems with the example. So only create it if you plan to
  # use the example.
  class Alternative
    include LogUtil

    LAYOUT_DESCRIPTION = <<~LOG
      Alternative language must be a code block followed optionally by a callout list
    LOG

    def initialize(document, lang, path)
      @document = document
      @lang = lang
      @path = path
      @counter = @document.attr 'alternative_language_counter', 0
      @listing_text = @colist_text = nil
      load
      finish_preparations if validate
    end

    ##
    # A block for the alternative listing that can be inserted into the main
    # document if we've successfully loaded, validated, and munged the
    # alternative. nil otherwise.
    def listing(parent)
      return unless @listing_text

      Asciidoctor::Block.new parent, :pass, source: @listing_text
    end

    ##
    # A block for the alternative callout list that can be inserted into the
    # main document if the alternative contains a callout list and we've
    # successfully loaded, validated, and munged the alternative. nil otherwise.
    def colist(parent)
      return unless @colist_text

      Asciidoctor::Block.new parent, :pass, source: @colist_text
    end

    def load
      # Parse the included portion as asciidoc but not as a "child" document
      # because that is for parsing text we've already parsed once. This is
      # text that we're detecting very late in the process.
      @child = Asciidoctor::Document.new "include::#{@path}[]", load_opts
      @child.parse
    end

    def load_opts
      {
        attributes: @document.attributes.dup,
        safe: @document.safe,
        backend: @document.backend,
        doctype: Asciidoctor::DEFAULT_DOCTYPE,
        sourcemap: @document.sourcemap,
        base_dir: @document.base_dir,
        to_dir: @document.options[:to_dir],
      }
    end

    def validate
      @listing, @colist, rest = @child.blocks
      unless @listing || !rest.empty?
        warn block: @child, message: <<~LOG.strip
          #{LAYOUT_DESCRIPTION} but was:
          #{@child.blocks}
        LOG
        return false
      end

      check_listing & check_colist
    end

    ##
    # Return false if the block in listing position isn't a listing or is
    # otherwise invalid. Otherwise returns true.
    def check_listing
      unless @listing.context == :listing
        warn block: @listing, message: <<~LOG.strip
          #{LAYOUT_DESCRIPTION} but the first block was a #{@listing.context}.
        LOG
        return false
      end

      validate_listing_langauge
    end

    def validate_listing_langauge
      unless (listing_lang = @listing.attr 'language') == @lang
        warn block: @listing, message: <<~LOG.strip
          Alternative language listing must have lang=#{@lang} but was #{listing_lang}.
        LOG
        return false
      end

      true
    end

    ##
    # Return false if block in the colist position isn't a colist.
    # Otherwise returns true.
    def check_colist
      return true unless @colist

      unless @colist.context == :colist
        warn block: @colist, message: <<~LOG.strip
          #{LAYOUT_DESCRIPTION} but the second block was a #{@colist.context}.
        LOG
        return false
      end
      true
    end

    ##
    # Finish preparing the alternative after we know it is valid.
    def finish_preparations
      munge
      @document.attributes['alternative_language_counter'] = @counter + 1
      @listing_text = @listing.convert
      @colist_text = @colist&.convert
    end

    ##
    # Munge the loaded document into something we can include in the
    # main document.
    def munge
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
