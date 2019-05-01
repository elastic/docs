# frozen_string_literal: true

require_relative 'dsl/convert_all'
require_relative 'dsl/convert_single'
require_relative 'dsl/file_contexts'

##
# Defines methods to create contexts and shared examples used in the tests.
module Dsl
  include ConvertAll
  include ConvertSingle
  include FileContexts
end
