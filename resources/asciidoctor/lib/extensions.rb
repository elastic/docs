# frozen_string_literal: true

require_relative 'alternative_language_lookup/extension'
require_relative 'care_admonition/extension'
require_relative 'change_admonition/extension'
require_relative 'chunker/extension'
require_relative 'copy_images/extension'
require_relative 'cramped_include/extension'
require_relative 'docbook_compat/extension'
require_relative 'edit_me/extension'
require_relative 'elastic_compat_tree_processor/extension'
require_relative 'elastic_compat_preprocessor/extension'
require_relative 'elastic_include_tagged/extension'
require_relative 'lang_override/extension'
require_relative 'open_in_widget/extension'
require_relative 'relativize_link/extension'

Asciidoctor::Extensions.register do
  # Enable storing the source locations so we can look at them. This is required
  # for EditMe to get a nice location.
  document.sourcemap = true
end
# Adding DocbookCompat first lets it help rendering things like the
# edit_me links
Asciidoctor::Extensions.register DocbookCompat
Asciidoctor::Extensions.register CareAdmonition
Asciidoctor::Extensions.register ChangeAdmonition
Asciidoctor::Extensions.register Chunker
Asciidoctor::Extensions.register CopyImages
Asciidoctor::Extensions.register EditMe
Asciidoctor::Extensions.register OpenInWidget
Asciidoctor::Extensions.register RelativizeLink
Asciidoctor::Extensions.register do
  block_macro LangOverride
  preprocessor CrampedInclude
  preprocessor ElasticCompatPreprocessor
  treeprocessor ElasticCompatTreeProcessor
  # The tree processors after this must come after ElasticComptTreeProcessor
  # or they won't see the right tree.
  treeprocessor AlternativeLanguageLookup::AlternativeLanguageLookup
  include_processor ElasticIncludeTagged
end
