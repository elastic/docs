# frozen_string_literal: true

require_relative 'change_admonishment/extension'
require_relative 'copy_images/extension'
require_relative 'cramped_include/extension'
require_relative 'edit_me/extension'
require_relative 'elastic_compat_tree_processor/extension'
require_relative 'elastic_compat_preprocessor/extension'
require_relative 'elastic_include_tagged/extension'

Extensions.register ChangeAdmonishment
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
