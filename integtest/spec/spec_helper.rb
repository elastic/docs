# frozen_string_literal: true

require_relative 'helper/dest'
require_relative 'helper/dsl'
require_relative 'helper/sh'
require_relative 'helper/source'

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

  config.extend Dsl
  config.include Sh
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
    msg + " but only #{entries.sort} exist"
  end
end

##
# Match the keys in two hashes, printing the extra or missing keys when there
# is a failure.
RSpec::Matchers.define :have_same_keys do |expected|
  match do |actual|
    expected_keys = expected.keys.sort
    actual_keys = actual.keys.sort
    expected_keys == actual_keys
  end
  failure_message do |actual|
    expected_keys = expected.keys.sort
    actual_keys = actual.keys.sort

    missing = expected_keys - actual_keys
    extra = actual_keys - expected_keys

    msg = 'expected keys to match exactly but'
    if missing
      msg += " missed:\n"
      missing.each { |k| msg += "#{k} => #{expected[k]}" }
      msg += "\nand" if extra
    end
    msg += " had extra:\n"
    extra.each { |k| msg += "#{k} => #{actual[k]}" }

    msg
  end
end
