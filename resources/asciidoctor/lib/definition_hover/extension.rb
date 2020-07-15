# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Extension for adding a definition to key terms in the docs
# Must be used inline. Does not have unique block formatting
#
# Usage
#
#   Foo definition:["word", "definition"]
#   I like to definition:[run,To move at a speed faster than a walk.]
#
class DefinitionAdmonition < Asciidoctor::Extensions::Group
  MACRO_CONF = [
    [:definition, 'word', 'definition'],
  ].freeze
  def activate(registry)
    MACRO_CONF.each do |(name, word, definition)|
      inline = ChangeAdmonitionInline.new word, definition
      registry.inline_macro inline, name
    end
  end

  ##
  # Inline change admonition.
  class ChangeAdmonitionInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl

    # Stores content passed in from asciidoc in `attrs[:x]`
    name_positional_attributes :input_word, :input_def

    # I don't know what this does, but it's necessary for this widget to work
    format :short

    def initialize(word, definition)
      super(nil)
      # I have no idea if this is necessary
      # I also have no idea what it does
      @word = word
      @definition = definition
    end

    def process(parent, _target, attrs)
      # Access attributes passed in from raw asciidoc
      input_word = attrs[:input_word]
      message = attrs[:input_def]

      # Create a new line block
      Asciidoctor::Inline.new(
        parent, :admonition, message, type: 'definition', attributes: {
          'input_word' => input_word,

          # These aren't needed. I'll delete them soon enough
          # 'word' => @word,
          # 'definition' => @definition,
        }
      )
    end
  end
end
