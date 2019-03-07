# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Extensions for marking when something as `beta` or `experimental`.
#
# Usage
#
#   beta::[]
#   experimental::[]
#   Foo beta:[]
#   Foo experimental:[]
#
class CareAdmonition < Asciidoctor::Extensions::Group
  def activate(registry)
    [
        [:beta, 'beta'],
        [:experimental, 'experimental'],
    ].each do |(name, role)|
      registry.block_macro ChangeAdmonitionBlock.new(role), name
      registry.inline_macro ChangeAdmonitionInline.new(role), name
    end
  end

  ##
  # Block care admonition.
  class ChangeAdmonitionBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :passtext

    def initialize(role)
      super(nil)
      @role = role
    end

    def process(parent, _target, attrs)
      Asciidoctor::Block.new(parent, :admonition,
          :source => attrs[:passtext],
          :attributes => {
            'role' => @role,
            'name' => 'warning',
            'style' => 'warning',
          })
    end
  end

  ##
  # Inline care admonition.
  class ChangeAdmonitionInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl
    name_positional_attributes :text
    with_format :short

    def initialize(role)
      super(nil)
      @role = role
    end

    def process(_parent, _target, attrs)
      if attrs[:text]
        <<~DOCBOOK
          <phrase role="#{@role}">
            #{attrs[:text]}
          </phrase>
        DOCBOOK
      else
        <<~DOCBOOK
          <phrase role="#{@role}"/>
        DOCBOOK
      end
    end
  end
end
