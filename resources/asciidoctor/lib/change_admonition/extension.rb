# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter.rb'

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
  def activate(registry)
    [
      [:added, 'added', 'note'],
      [:coming, 'changed', 'note'],
      [:deprecated, 'deleted', 'warning'],
    ].each do |(name, revisionflag, tag)|
      registry.block_macro ChangeAdmonitionBlock.new(revisionflag, tag), name
      registry.inline_macro ChangeAdmonitionInline.new(revisionflag), name
    end
    DelegatingConverter.setup(registry.document) { |doc| Converter.new doc }
  end

  ##
  # Properly renders change admonitions.
  class Converter < DelegatingConverter
    def convert_admonition(node)
      return yield unless (flag = node.attr 'revisionflag')

      <<~DOCBOOK.strip
        <#{tag_name = node.attr 'name'} revisionflag="#{flag}" revision="#{node.attr 'version'}">
        <simpara>#{node.content}</simpara>
        </#{tag_name}>
      DOCBOOK
    end
  end

  ##
  # Block change admonition.
  class ChangeAdmonitionBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :version, :passtext

    def initialize(revisionflag, tag)
      super(nil)
      @revisionflag = revisionflag
      @tag = tag
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      Asciidoctor::Block.new(
        parent, :admonition,
        attributes: {
          'name' => @tag,
          'revisionflag' => @revisionflag,
          'version' => version,
        },
        source: attrs[:passtext]
      )
    end
  end

  ##
  # Inline change admonition.
  class ChangeAdmonitionInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl
    name_positional_attributes :version, :text
    format :short

    def initialize(revisionflag)
      super(nil)
      @revisionflag = revisionflag
    end

    def process(parent, _target, attrs)
      Asciidoctor::Inline.new(parent, :quoted, text(attrs))
    end

    def text(attrs)
      if attrs[:text]
        <<~DOCBOOK
          <phrase revisionflag="#{@revisionflag}" revision="#{attrs[:version]}">
            #{attrs[:text]}
          </phrase>
        DOCBOOK
      else
        <<~DOCBOOK
          <phrase revisionflag="#{@revisionflag}" revision="#{attrs[:version]}"/>
        DOCBOOK
      end
    end
  end
end
