# frozen_string_literal: true

require_relative '../delegating_converter'

module AlternativeLanguageLookup
  ##
  # A Converter that adds an anchor above each listing with its digest.
  class Converter < DelegatingConverter
    def convert_listing(node)
      return yield unless (digest = node.attr 'digest')

      %(<a id="#{digest}"></a>\n) + yield
    end
  end
end
