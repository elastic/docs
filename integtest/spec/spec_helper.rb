# frozen_string_literal: true

require_relative 'helper/convert'
require_relative 'helper/dsl'
require_relative 'helper/sh'

require 'tmpdir'
require 'fileutils'

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

  config.include Convert
  config.extend Dsl
  config.include Sh
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
# Build a path to a file in the destination.
def dest_file(file)
  File.expand_path(file, @dest)
end

##
# Return a list of the paths of all files in a directory relative to
# that directory.
def files_in(dir)
  Dir.chdir(dir) do
    Dir.glob('**/*').select { |f| File.file?(f) }
  end
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
    return msg unless Dir.exist? parent

    entries = Dir.entries(parent).reject { |e| e.start_with? '.' }
    msg + " but only #{entries} exist"
  end
end
