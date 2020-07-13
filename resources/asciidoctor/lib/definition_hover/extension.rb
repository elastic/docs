# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Extension for adding a definition to key terms in the docs
#
# Usage
#
#   definition::["word", "definition"]
#   Foo definition:["word", "definition"]
#
class DefinitionAdmonition < Asciidoctor::Extensions::Group
  MACRO_CONF = [
    [:definition, 'word', 'definition', nil, nil],
  ].freeze
  def activate(registry)
    MACRO_CONF.each do |(name, revisionflag, tag, message, title_class)|
      block = ChangeAdmonitionBlock.new revisionflag, tag, message
      inline = ChangeAdmonitionInline.new message, title_class
      registry.block_macro block, name
      registry.inline_macro inline, name
    end
  end

  ##
  # Block change admonition.
  class ChangeAdmonitionBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :version, :passtext

    def initialize(revisionflag, tag, message)
      super(nil)
      @revisionflag = revisionflag
      @tag = tag
      @message = message
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      passtext = attrs[:passtext]
      text = "#{@message} #{version}."
      source = passtext || text
      Asciidoctor::Block.new parent, :admonition, source: source, attributes: {
        'name' => @tag,
        'revisionflag' => @revisionflag,
        'version' => version,
        'title' => passtext ? text : nil,
      }
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
