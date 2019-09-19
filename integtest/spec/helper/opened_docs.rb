# frozen_string_literal: true

require 'open3'

require_relative 'serving_docs'

class OpenedDocs < ServingDocs
  ##
  # Reads the logs of the preview without updating them from the subprocess.
  attr_reader :logs

  def initialize(cmd)
    super cmd

    wait_for_logs(/start worker processes$/, 60)
  end
end
