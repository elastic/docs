# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Extensions for marking when something was added, when it *will* be added, or
# when it was deprecated.
#
# Usage
#
#   added::[6.0.0-beta1]
#   coming::[6.0.0-beta1]
#   deprecated::[6.0.0-beta1]
#   Foo added:[6.0.0-beta1]
#   Foo coming:[6.0.0-beta1]
#   Foo deprecated:[6.0.0-beta1]
#
class ChangeAdmonition < Asciidoctor::Extensions::Group
  MACRO_CONF = [
    [:added, 'added', 'note', 'Added in', ' version-added'],
    [:coming, 'changed', 'note', 'Coming in', ' version-coming'],
    [:deprecated, 'deleted', 'warning', 'Deprecated in', ' version-deprecated'],
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
      message = "#{@message} #{version}."
      message += ' ' + attrs[:text] if attrs[:text]
      Asciidoctor::Inline.new(
        parent, :admonition, message, type: 'change', attributes: {
          'title_type' => 'version',
          'title_class' => "#{@extra_title_class}",
          'title' => version,
        }
      )
    end
  end
end
