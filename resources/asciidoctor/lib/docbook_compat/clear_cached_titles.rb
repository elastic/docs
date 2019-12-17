# frozen_string_literal: true

require_relative '../scaffold'

module DocbookCompat
  ##
  # Clears the internal cache of the title's conversion on sections that look
  # like they have generated ids. This is because when we generate ids we
  # convert titles differently.
  class ClearCachedTitles < TreeProcessorScaffold
    def process_block(block)
      return unless %i[section floating_title].include? block.context
      return unless block.id&.start_with?(block.attr('idprefix') || '_')

      block.instance_variable_set :@converted_title, nil
    end
  end
end
