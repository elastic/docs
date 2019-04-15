# frozen_string_literal: true

require 'digest'
require_relative 'dsl/convert_contexts'
require_relative 'dsl/file_contexts'

##
# Defines methods to create contexts for converting asciidoc files to html.
module Dsl
  include ConvertContexts
  include FileContexts
end
