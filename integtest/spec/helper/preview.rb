# frozen_string_literal: true

require 'open3'

class Preview
  ##
  # Reads the logs of the preview without updating them from the subprocess.
  attr_reader :logs

  def initialize(bare_repo)
    _stdin, @out, @wait_thr = Open3.popen2e(
      '/docs_build/build_docs.pl', '--in_standard_docker', '--preview',
      '--target_repo', bare_repo
    )
    @logs = ''

    wait_for_logs(/^preview server is listening on 3000$/, 10)
  end

  ##
  # Waits for the logs to match a regex. The timeout is in seconds.
  def wait_for_logs(regexp, timeout)
    start = Time.now
    loop do
      return if regexp =~ read_preview_logs
      if Time.now - start > timeout
        raise "Logs don't match [#{regexp}]:\n#{logs}"
      end

      sleep 0.1
    end
  end

  ##
  # Kill the preview.
  def exit
    Process.kill 'TERM', @wait_thr.pid
    @wait_thr.exit
    wait_for_logs(/^Terminated preview services$/, 10)
  end

  private

  ##
  # Reads some preview logs from the preview subprocess if there are any ready
  # and returns all logs we've read.
  def read_preview_logs
    @logs += @out.read_nonblock(10_000)
  rescue IO::WaitReadable
    # There isn't any data available, just return what we have
    @logs
  end
end
