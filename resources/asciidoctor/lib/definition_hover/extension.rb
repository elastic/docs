# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Extension for adding an inline definition to key terms in the docs
#
# Usage
#
#   Foo definition:["word", "definition"]
#   I like to definition:[run,To move at a speed faster than a walk.]
#
class DefinitionAdmonition < Asciidoctor::Extensions::Group
  def activate(registry)
    registry.inline_macro Definition.new :definition
  end

  # Inline change admonition.
  class Definition < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl

    # Stores content passed in from asciidoc in `attrs[:x]`
    name_positional_attributes :input_word, :input_def

    # I don't know what this does, but it's necessary for this widget to work
    format :short

    def process(parent, _target, attrs)
      # Access attributes passed in from raw asciidoc
      input_word = attrs[:input_word]
      message = attrs[:input_def]

      # Create a new line block
      Asciidoctor::Inline.new(
        parent, :admonition, message, type: 'definition', attributes: {
          'input_word' => input_word,
        }
      )
    end
  end
end
