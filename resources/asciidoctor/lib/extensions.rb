require_relative 'elastic_compat/extension'
require_relative 'added/extension'

Extensions.register do
  preprocessor ElasticCompatPreprocessor
  block_macro AddedBlock
end