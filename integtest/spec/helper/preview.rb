# frozen_string_literal: true

require 'open3'

require_relative 'serving_docs'

class Preview < ServingDocs
  ##
  # Reads the logs of the preview without updating them from the subprocess.
  attr_reader :logs

  def initialize(bare_repo, air_gapped: false)
    super [
      '/docs_build/build_docs.pl', '--in_standard_docker',
      '--preview', '--target_repo', bare_repo
    ].concat(air_gapped ? ['--gapped'] : [])

    wait_for_logs(/^preview server is listening on 3000$/, 60)
  end
end
