# frozen_string_literal: true

require_relative 'care_admonition/extension'
require_relative 'change_admonition/extension'
require_relative 'copy_images/extension'
require_relative 'cramped_include/extension'
require_relative 'edit_me/extension'
require_relative 'elastic_compat_tree_processor/extension'
require_relative 'elastic_compat_preprocessor/extension'
require_relative 'elastic_include_tagged/extension'
require_relative 'lang_override/extension'
require_relative 'open_in_widget/extension'

Asciidoctor::Extensions.register CareAdmonition
Asciidoctor::Extensions.register ChangeAdmonition
Asciidoctor::Extensions.register do
  # Enable storing the source locations so we can look at them. This is required
  # for EditMe to get a nice location.
  document.sourcemap = true
  block_macro LangOverride
  preprocessor CrampedInclude
  preprocessor ElasticCompatPreprocessor
  treeprocessor CopyImages::CopyImages
  treeprocessor EditMe
  treeprocessor ElasticCompatTreeProcessor
  treeprocessor OpenInWidget
  include_processor ElasticIncludeTagged
end
