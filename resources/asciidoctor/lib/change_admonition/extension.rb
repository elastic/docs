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
    [:added, 'added', 'note', 'Added in', 'version-added'],
    [:coming, 'changed', 'note', 'Coming in', 'version-coming'],
    [:deprecated, 'deleted', 'warning', 'Deprecated in', 'version-deprecated'],
  ].freeze
  def activate(registry)
    MACRO_CONF.each do |(name, revisionflag, tag, message, title_class)|
      block = ChangeAdmonitionBlock.new revisionflag, tag, message, title_class
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

    def initialize(revisionflag, tag, message, title_class)
      super(nil)
      @revisionflag = revisionflag
      @tag = tag
      @message = message
      @title_class = title_class
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      passtext = attrs[:passtext]
      text = "#{@message} #{version}"
      name = "#{@tag} #{@title_class}"
      source = passtext || nil
      Asciidoctor::Block.new parent, :admonition, source: source, attributes: {
        'name' => name,
        'revisionflag' => @revisionflag,
        'version' => version,
        'title' => text,
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
      @message_title
      @extra_title_class = extra_title_class
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      message_title = "#{@message} #{version}"
      message = attrs[:text] ? attrs[:text] : nil
      Asciidoctor::Inline.new(
        parent, :admonition, message, type: 'change', attributes: {
          'title_type' => 'version',
          'title_class' => "#{@extra_title_class}",
          'title' => version,
          'message_title' => message_title,
          'name' => 'change'
        }
      )
    end
  end
end
