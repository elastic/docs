# frozen_string_literal: true

require_relative 'helper/matcher/doc_body'
require_relative 'helper/matcher/have_same_keys'
require_relative 'helper/matcher/initial_js_state'
require_relative 'helper/matcher/serve'
require_relative 'helper/console_alternative_examples'
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

def indent(str, indentation)
  str.split("\n").map { |s| indentation + s }.join "\n"
end

##
# Match paths that refer to an existing file.
# Prefer this instead of `expect(File).to exist('path')` because the failure
# message is worlds better
RSpec::Matchers.define :file_exist do
  # TODO: move to helper/matcher/file_exists.rb
  match do |actual|
    File.exist? actual
  end
  failure_message do |actual|
    msg = "expected that #{actual} exists"
    parent = File.expand_path '..', actual
    parent = File.expand_path '..', parent until Dir.exist? parent

    entries = Dir.entries(parent).reject { |e| e.start_with? '.' }
    msg + " but only #{parent}/#{entries.sort} exist"
  end
end
