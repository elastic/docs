# frozen_string_literal: true

require 'asciidoctor/logging'

##
# Utilities for logging in a way that makes asciidoctor happy.
module LogUtil
  include Asciidoctor::Logging

  def error(location: nil, block: nil, message:)
    location ||= block&.source_location
    logger.error message_with_context message, source_location: location
  end

  def warn(location: nil, block: nil, message:)
    location ||= block&.source_location
    logger.warn message_with_context message, source_location: location
  end

  def info(location: nil, block: nil, message:)
    location ||= block&.source_location
    logger.info message_with_context message, source_location: location
  end
end
