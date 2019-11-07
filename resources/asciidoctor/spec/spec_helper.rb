# frozen_string_literal: true

require 'docbook45/converter'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Put asciidoctor into verbose mode so it'll log reference errors
$VERBOSE = true

##
# Used by the `convert with logs` and `convert without logs` contexts
def internal_convert(input, convert_logger, backend, extra_attributes)
  attributes = { 'docdir' => File.dirname(__FILE__) }
  attributes.merge! extra_attributes
  args = internal_convert_args convert_logger, backend, attributes
  Asciidoctor.convert input, args
end

def internal_convert_args(convert_logger, backend, attributes)
  {
    safe: :unsafe, # Used to include "funny" files.
    backend: backend,
    logger: convert_logger,
    doctype: :book,
    attributes: attributes,
    sourcemap: true, # Required by many of our plugins
  }
end

##
# Converts asciidoc to docbook and sets logs to `logs`
#
# In:
#   input            - asciidoc text to convert
#   backend          - the conversion backend - defaults to :docbook45
#   extra_attributes - attributes added to the conversion - defaults to {}
#
# Out:
#   converted        - converted docbook text
#   logs             - lines logged
RSpec.shared_context 'convert with logs' do
  let(:convert_logger) { Asciidoctor::MemoryLogger.new }
  let(:converted) do
    # Using let! here would stop us from having to explicitly evaluate
    # `converted` in the let for `logs` but it'd cause `converted` to be
    # evaluated before `before(:example)` blocks
    extra_attributes = defined?(convert_attributes) ? convert_attributes : {}
    explicit_backend = defined?(backend) ? backend : :docbook45
    internal_convert input, convert_logger, explicit_backend, extra_attributes
  end
  let(:logs) do
    # Evaluate converted because it populates the logger as a side effect.
    converted
    # Now render the logs.
    convert_logger.messages
                  .map { |l| "#{l[:severity]}: #{l[:message].inspect}" }
                  .join("\n")
  end
end

##
# Converts asciidoc to docbook, asserting that nothing is logged during the
# conversion.
#
# In:
#   input            - asciidoc text to convert
#   backend          - the conversion backend - defaults to :docbook45
#   extra_attributes - attributes added to the conversion - defaults to {}
#
# Out:
#   converted        - converted docbook text
RSpec.shared_context 'convert without logs' do
  let(:converted) do
    convert_logger = Asciidoctor::MemoryLogger.new
    extra_attributes = defined?(convert_attributes) ? convert_attributes : {}
    explicit_backend = defined?(backend) ? backend : :docbook45
    converted = internal_convert(
      input, convert_logger, explicit_backend, extra_attributes
    )
    if convert_logger.messages.empty? == false
      raise "Expected no logs but got:\n" +
            convert_logger.messages
                          .map { |l| "#{l[:severity]}: #{l[:message].inspect}" }
                          .join("\n")
    end
    converted
  end
end

##### TODO: This should be shared with integ tests
##
# Create a context to assert things about a file. By default it just
# asserts that the file was created but if you pass a block you can add
# assertions on `contents`.
def file_context(name, file_name = name, &block)
  context "for #{name}" do
    include_context 'Dsl_file', file_name

    # Yield to the block to add more tests.
    class_exec(&block) if block
  end
end
RSpec.shared_context 'Dsl_file' do |file_name|
  let(:file) do
    converted # force the conversion so the file will exist
    File.join outdir, file_name
  end
  let(:contents) do
    File.open file, 'r:UTF-8', &:read if File.exist? file
  end

  it 'is created' do
    expect(file).to file_exist
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
    parent = File.expand_path '..', actual
    parent = File.expand_path '..', parent until Dir.exist? parent

    entries = Dir.entries(parent).reject { |e| e.start_with? '.' }
    msg + " but only #{parent}/#{entries.sort} exist"
  end
end
