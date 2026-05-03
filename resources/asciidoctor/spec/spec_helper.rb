# frozen_string_literal: true

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
def internal_convert(
    input, convert_logger, standalone, extra_attributes
  )
  attributes = { 'docdir' => File.dirname(__FILE__) }
  attributes.merge! extra_attributes
  args = internal_convert_args convert_logger, standalone, attributes
  Asciidoctor.convert input, args
end

def internal_convert_args(convert_logger, standalone, attributes)
  {
    safe: :unsafe, # Used to include "funny" files.
    logger: convert_logger,
    standalone: standalone,
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
    explicit_standalone = defined?(standalone) ? standalone : false
    internal_convert(
      input,
      convert_logger,
      explicit_standalone,
      extra_attributes
    )
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
#   extra_attributes - attributes added to the conversion - defaults to {}
#
# Out:
#   converted        - converted docbook text
RSpec.shared_context 'convert without logs' do
  let(:converted) do
    convert_logger = Asciidoctor::MemoryLogger.new
    extra_attributes = defined?(convert_attributes) ? convert_attributes : {}
    explicit_standalone = defined?(standalone) ? standalone : false
    converted = internal_convert(
      input,
      convert_logger,
      explicit_standalone,
      extra_attributes
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
