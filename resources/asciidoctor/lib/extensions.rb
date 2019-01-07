require_relative 'added/extension'
require_relative 'edit_me/extension'
require_relative 'elastic_compat_tree_processor/extension'
require_relative 'elastic_compat_preprocessor/extension'
require_relative 'elastic_include_tagged/extension'

Extensions.register do
  # Enable storing the source locations so we can look at them. This is required
  # for EditMe to get a nice location.
  document.sourcemap = true
  preprocessor ElasticCompatPreprocessor
  treeprocessor EditMe
  treeprocessor ElasticCompatTreeProcessor
  include_processor ElasticIncludeTagged
  block_macro AddedBlock
end
