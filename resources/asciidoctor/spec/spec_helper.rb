# frozen_string_literal: true

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Put asciidoctor into verbose mode so it'll log reference errors
$VERBOSE = true

##
# Convert an asciidoc string into docbook.
def convert(input, extra_attributes = {}, warnings_matcher = eq(''))
  logger = Asciidoctor::MemoryLogger.new
  attributes = {
    'docdir' => File.dirname(__FILE__),
  }
  attributes.merge! extra_attributes
  result = Asciidoctor.convert input,
      safe:       :unsafe,  # Used to include "funny" files.
      backend:    :docbook45,
      logger:     logger,
      doctype:    :book,
      attributes: attributes,
      sourcemap:  true
  warnings_string = logger.messages
        .map { |l| "#{l[:severity]}: #{l[:message].inspect}" }
        .join("\n")
  expect(warnings_string).to warnings_matcher
  result
end

##
# Used by the `convert with logs` and `convert without logs` contexts
def internal_convert(input, convert_logger, extra_attributes)
  attributes = {
    'docdir' => File.dirname(__FILE__),
  }
  attributes.merge! extra_attributes
  Asciidoctor.convert input,
      safe:       :unsafe,  # Used to include "funny" files.
      backend:    :docbook45,
      logger:     convert_logger,
      doctype:    :book,
      attributes: attributes,
      sourcemap:  true
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
  let!(:converted) do
    # We use let! here to force the conversion because it populates the logger
    extra_attributes = defined?(convert_attributes) ? convert_attributes : {}
    internal_convert input, convert_logger, extra_attributes
  end
  let(:logs) do
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
RSpec.shared_context 'convert no logs' do
  let(:converted) do
    convert_logger = Asciidoctor::MemoryLogger.new
    extra_attributes = defined?(convert_attributes) ? convert_attributes : {}
    converted = internal_convert input, convert_logger, extra_attributes
    if convert_logger.messages.empty? == false
      raise "Expected no logs but got:\n" +
        convert_logger.messages
          .map { |l| "#{l[:severity]}: #{l[:message].inspect}" }
          .join("\n")
    end
    converted
  end
end
