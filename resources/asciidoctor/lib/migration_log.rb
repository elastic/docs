# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Infrastructure for logging migration warnings.
module MigrationLog
  include Asciidoctor::Logging

  ##
  # Emit a migration warning if migration warnings are enabled overall and if
  # this particular migration warning is enabled.
  def migration_warn(block, cursor, key, message)
    # We have to play the block's attributes against the document, then clear
    # them on the way out so we can override this behavior inside a block.
    block.document.playback_attributes block.attributes
    return unless block.attr('migration-warnings', 'true') == 'true'
    return unless block.attr("migration-warning-#{key}", 'true') == 'true'

    logger.warn message_with_context "MIGRATION: #{message}",
                                     source_location: cursor
  ensure
    block.document.clear_playback_attributes block.attributes
  end
end
