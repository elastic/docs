# frozen_string_literal: true

require_relative 'dsl/convert_contexts'
require_relative 'dsl/file_contexts'

##
# Defines methods to create contexts and shared examples used in the tests.
module Dsl
  include FileContexts
  include ConvertContexts
end
