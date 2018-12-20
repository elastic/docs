require_relative 'added/extension'
require_relative 'elastic_compat/extension'
require_relative 'include_tagged/extension'

Extensions.register do
  preprocessor ElasticCompatPreprocessor
  block_macro AddedBlock
  inline_macro IncludeTagged
end