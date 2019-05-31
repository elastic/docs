# frozen_string_literal: true

require 'open3'

require_relative 'opened_docs'
require_relative 'preview'
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
  # Create the fluent builder that you can use to convert a single book.
  def prepare_convert_single(from, to)
    ConvertSingle.new from, to, self
  end

  ##
  # Convert a single book.
  def convert_single(from, to,
                     expect_failure: false,
                     suppress_migration_warnings: false,
                     asciidoctor:)
    # TODO: replace all calls with prepare_convert_single
    convert = prepare_convert_single from, to
    convert.asciidoctor if asciidoctor
    convert.suppress_migration_warnings if suppress_migration_warnings
    convert.convert expect_failure: expect_failure
  end

  def prepare_convert_all(conf)
    ConvertAll.new conf, bare_repo, self
  end

  ##
  # Convert a conf file worth of books and check it out.
  def convert_all(conf, expect_failure: false, target_branch: nil)
    # TODO: remove this in favor of prepare_convert_all
    convert = ConvertAll.new conf, bare_repo, self
    convert.target_branch target_branch if target_branch
    convert.convert(expect_failure: expect_failure)
  end

  ##
  # Checks out the results of the last call to convert_all
  def checkout_conversion(branch: nil)
    branch_cmd = ''
    branch_cmd = "--branch #{branch} " if branch
    sh "git clone #{branch_cmd}#{bare_repo} #{@dest}"
  end

  ##
  # Start the preview service.
  def start_preview
    Preview.new(bare_repo)
  end

  def remove_target_brach(branch_name)
    Dir.chdir bare_repo do
      sh "git branch -D #{branch_name}"
    end
  end

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

  def run_convert_and_open(cmd)
    cmd.unshift '/docs_build/build_docs.pl', '--in_standard_docker'
    cmd += ['--open']
    OpenedDocs.new cmd
  end

  class CmdBuilder
    def open
      @dest.run_convert_and_open @cmd
    end

    def convert(expect_failure: false)
      @dest.run_convert @cmd, expect_failure
    end
  end

  class ConvertSingle < CmdBuilder
    def initialize(from, to, dest)
      @cmd = %W[
        --doc #{from}
        --out #{dest.path(to)}
      ]
      @dest = dest
    end

    def asciidoctor
      @cmd += ['--asciidoctor']
      self
    end

    def suppress_migration_warnings
      @cmd += ['--suppress_migration_warnings']
      self
    end
  end

  class ConvertAll < CmdBuilder
    def initialize(conf, target_repo, dest)
      @cmd = %W[
        --all
        --push
        --target_repo #{target_repo}
        --conf #{conf}
      ]
      @dest = dest
    end

    def target_branch(target_branch)
      @cmd += ['--target_branch', target_branch]
      self
    end

    def skip_link_check
      @cmd += ['--skiplinkcheck']
      self
    end

    def keep_hash
      @cmd += ['--keep_hash']
      self
    end

    def sub_dir(repo, branch)
      @cmd += ['--sub_dir', "#{repo.name}:#{branch}:#{repo.root}"]
      self
    end
  end
end
