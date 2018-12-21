require_relative 'added/extension'
require_relative 'elastic_compat/extension'
require_relative 'elastic_include_tagged/extension'

Extensions.register do
  preprocessor ElasticCompatPreprocessor
  include_processor ElasticIncludeTagged
  block_macro AddedBlock
end