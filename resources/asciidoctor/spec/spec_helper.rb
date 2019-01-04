require "bundler/setup"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

##
# Error thrown when the conversion results in a warning.
class ConvertError < Exception
  attr_reader :warnings
  attr_reader :result

  def initialize warnings, result
    super('\n' + 
        warnings
          .map { |l| "#{l[:severity]}: #{l[:message].inspect}" }
          .join('\n'))
    @warnings = warnings
    @result = result
  end
end

# Put asciidoctor into verbose mode so it'll log reference errors
$VERBOSE = true

##
# Convert an asciidoc string into docbook. If the conversion results in any
# errors or warnings then raises a ConvertError.
def convert input, extra_attributes = {}
  logger = Asciidoctor::MemoryLogger.new
  attributes = {
    'docdir' => File.dirname(__FILE__),
  }
  attributes.merge! extra_attributes
  result = Asciidoctor.convert input, {
      :safe       => :unsafe,  # Used to include "funny" files.
      :backend    => :docbook45,
      :logger     => logger,
      :doctype    => :book,
      :attributes => attributes,
      :sourcemap  => true,
    }
  if logger.messages != [] then
    raise ConvertError.new(logger.messages, result)
  end
  result
end
