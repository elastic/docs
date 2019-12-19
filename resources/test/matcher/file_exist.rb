# frozen_string_literal: true

##
# Match paths that refer to an existing file.
# Prefer this instead of `expect(File).to exist('path')` because the failure
# message is worlds better.
RSpec::Matchers.define :file_exist do
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
