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
    [:definition, 'word', 'definition', nil, nil],
  ].freeze
  def activate(registry)
    MACRO_CONF.each do |(name, revisionflag, tag, message, title_class)|
      inline = ChangeAdmonitionInline.new message, title_class
      registry.inline_macro inline, name
    end
  end

  ##
  # Inline change admonition.
  class ChangeAdmonitionInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl
    name_positional_attributes :version, :text
    format :short

    def initialize(message, extra_title_class)
      super(nil)
      @message = message
      @extra_title_class = extra_title_class
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      message = "#{@message}" + attrs[:text] if attrs[:text]
      Asciidoctor::Inline.new(
        parent, :admonition, message, type: 'definition', attributes: {
          'title_type' => 'version',
          'title' => version,
        }
      )
    end
  end
end
