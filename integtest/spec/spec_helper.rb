# frozen_string_literal: true

require_relative 'helper/matcher/doc_body'
require_relative '../../resources/test/dsl/file_context'
require_relative '../../resources/test/matcher/file_exist'
require_relative 'helper/matcher/have_same_keys'
require_relative 'helper/matcher/initial_js_state'
require_relative 'helper/matcher/redirect_to'
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

def indent(str, indentation)
  str.split("\n").map { |s| indentation + s }.join "\n"
end

##
# Replace symbols in hash keys with their to_s. Building hashes out of symbols
# is much more "ruby", but those symbols make "funny" keys when you convert the
# hash into yaml.
def desymbolize_keys(thing)
  if thing.is_a? Hash
    thing.each_with_object({}) { |(k, v), r| r[k.to_s] = desymbolize_keys v }
  elsif thing.is_a? Array
    thing.map { |v| desymbolize_keys v }
  else
    thing
  end
end
