require_relative 'added/extension'
require_relative 'elastic_compat_tree_processor/extension'
require_relative 'elastic_compat_preprocessor/extension'
require_relative 'elastic_include_tagged/extension'

Extensions.register do
  preprocessor ElasticCompatPreprocessor
  treeprocessor ElasticCompatTreeProcessor
  include_processor ElasticIncludeTagged
  block_macro AddedBlock
end