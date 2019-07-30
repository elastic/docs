# frozen_string_literal: true

module AlternativeLanguageLookup
  ##
  # Finds and loads alternative examples in alternative languages.
  module AlternativeValidation
    include Asciidoctor::Logging

    LAYOUT_DESCRIPTION = <<~LOG
      Alternative language must be a code block followed optionally by a callout list
    LOG

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

      @source = @child.blocks[0]
      @colist = @child.blocks[1]
      check_source & check_colist
    end

    ##
    # Return false if the block in source position isn't a listing or is
    # otherwise invalid. Otherwise returns true.
    def check_source
      unless @source.context == :listing
        warn_child @source.source_location, <<~LOG.strip
          #{LAYOUT_DESCRIPTION} but the first block was a #{@source.context}.
        LOG
        return false
      end
      unless (lang = @source.attr 'language') == @alternative[:lang]
        warn_child @source.source_location, <<~LOG.strip
          Alternative language source must have lang=#{@alternative[:lang]} but was #{lang}.
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
        warn_child @colist.source_location, <<~LOG.strip
          #{LAYOUT_DESCRIPTION} but the second block was a #{@colist.context}.
        LOG
        return false
      end
      true
    end

    def warn_child(location, message)
      logger.warn message_with_context message, source_location: location
    end
  end
end
