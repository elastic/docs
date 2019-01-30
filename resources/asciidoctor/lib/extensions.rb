require_relative 'added/extension'
require_relative 'copy_images/extension'
require_relative 'cramped_include/extension'
require_relative 'edit_me/extension'
require_relative 'elastic_compat_tree_processor/extension'
require_relative 'elastic_compat_preprocessor/extension'
require_relative 'elastic_include_tagged/extension'

# This extensions is special because it is evil - just loading it is enough
require_relative 'inline_callout/extension'

Extensions.register Added
Extensions.register do
  # Enable storing the source locations so we can look at them. This is required
  # for EditMe to get a nice location.
  document.sourcemap = true
  preprocessor CrampedInclude
  preprocessor ElasticCompatPreprocessor
  treeprocessor CopyImages
  treeprocessor EditMe
  treeprocessor ElasticCompatTreeProcessor
  include_processor ElasticIncludeTagged
end
