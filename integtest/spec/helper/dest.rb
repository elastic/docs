# frozen_string_literal: true

require 'open3'

require_relative 'sh'

##
# Helper class for initiating a conversion and dealing with the results.
class Dest
  include Sh

  ##
  # Stdout and stderr of running the conversions in convert_single
  # or convert_all.
  attr_reader :convert_outputs

  ##
  # Status of the conversions. If any conversion fails it'll raise an error
  # unless called with expect_failure. If it is called with expect_failure
  # then it'll fail if there *isn't* a failure.
  attr_reader :convert_statuses

  def initialize(tmp)
    @bare_dest = File.expand_path 'dest.git', tmp
    @dest = File.expand_path 'dest', tmp
    Dir.mkdir @dest
    @initialized_bare_repo = false
    @convert_outputs = []
    @convert_statuses = []
  end

  ##
  # Expands a path relative to the destination.
  def path(relative_path)
    File.expand_path relative_path, @dest
  end

  ##
  # Convert a single book.
  def convert_single(from, to,
                     expect_failure: false,
                     suppress_migration_warnings: false,
                     asciidoctor:)
    cmd = %W[--doc #{from} --out #{path(to)}]
    cmd += ['--asciidoctor'] if asciidoctor
    cmd += ['--suppress_migration_warnings'] if suppress_migration_warnings
    run_convert(cmd, expect_failure)
  end

  ##
  # Convert a conf file worth of books and check it out.
  def convert_all(conf, expect_failure: false)
    cmd = %W[
      --all
      --push
      --target_repo #{bare_repo}
      --conf #{conf}
    ]
    run_convert(cmd, expect_failure)
  end

  ##
  # Checks out the results of the last call to convert_all
  def checkout_conversion
    sh "git clone #{bare_repo} #{@dest}"
  end

  private

  ##
  # The location of the bare repository. the first time this is called in a
  # given context the bare repository is initialized
  def bare_repo
    unless @initialized_bare_repo
      sh "git init --bare #{@bare_dest}"
      @initialized_bare_repo = true
    end
    @bare_dest
  end

  def run_convert(cmd, expect_failure)
    cmd.unshift '/docs_build/build_docs.pl', '--in_standard_docker'
    # Use popen here instead of capture to keep stdin open to appease the
    # docker-image-always-removed paranoia in build_docs.pl
    _stdin, out, wait_thr = Open3.popen2e(*cmd)
    status = wait_thr.value
    out = out.read
    ok = status.success?
    ok = !ok if expect_failure
    raise_status cmd, out, status unless ok

    @convert_outputs << out
    @convert_statuses << status.exitstatus
  end
end
