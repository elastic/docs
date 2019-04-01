# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'open3'

ENV['GIT_AUTHOR_NAME'] = 'Test'
ENV['GIT_AUTHOR_EMAIL'] = 'test@example.com'
ENV['GIT_COMMITTER_NAME'] = 'Test'
ENV['GIT_COMMITTER_EMAIL'] = 'test@example.com'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec.shared_context 'tmp dirs' do
  before(:context) do
    @tmp = Dir.mktmpdir
    @src = File.join @tmp, 'src'
    @dest = File.join @tmp, 'dest'
    Dir.mkdir @src
    Dir.mkdir @dest
  end

  after(:context) do
    FileUtils.remove_entry @tmp
  end
end

##
# Execute a command and return the result. Use this to execute commands in
# `before` sections to prepare the environment to test.
def sh(cmd)
  out, status = Open3.capture2e cmd
  return out if status.success?

  raise_status cmd, out, status
end

def raise_status(cmd, out, status)
  outmsg = out == '' ? '' : " with stdout/stderr:\n#{out}"
  raise "#{status.stopsig} [#{cmd}] returned [#{status}]#{outmsg}"
end

##
# Match paths that refer to an existing file.
# Prefer this instead of `expect(File).to exist('path')` because the failure
# message is worlds better
RSpec::Matchers.define :file_exist do
  match do |actual|
    File.exist? actual
  end
  failure_message do |actual|
    msg = "expected that #{actual} exists"
    parent = File.expand_path('..', actual)
    msg unless Dir.exist? parent

    entries = Dir.entries(parent).reject { |e| e.start_with? '.' }
    msg + " but only #{entries} exist"
  end
end
