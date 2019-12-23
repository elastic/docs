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
  BETA_DEFAULT_TEXT = <<~TEXT.strip
    This functionality is in beta and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.
  TEXT
  EXPERIMENTAL_DEFAULT_TEXT = <<~TEXT.strip
    This functionality is experimental and may be changed or removed completely in a future release. Elastic will take a best effort approach to fix any issues, but experimental features are not subject to the support SLA of official GA features.
  TEXT

  def activate(registry)
    [
      [:beta, 'beta', BETA_DEFAULT_TEXT],
      [:experimental, 'experimental', EXPERIMENTAL_DEFAULT_TEXT],
    ].each do |(name, role, default_text)|
      registry.block_macro ChangeAdmonitionBlock.new(role, default_text), name
      registry.inline_macro ChangeAdmonitionInline.new(role, default_text), name
    end
  end

  ##
  # Block care admonition.
  class ChangeAdmonitionBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :passtext

    def initialize(role, default_text)
      super(nil)
      @role = role
      @default_text = default_text
    end

    def process(parent, _target, attrs)
      Asciidoctor::Block.new(
        parent, :admonition,
        source: attrs[:passtext] || @default_text,
        attributes: {
          'role' => @role,
          'name' => 'warning',
          'style' => 'warning',
        }
      )
    end
  end

  ##
  # Inline care admonition.
  class ChangeAdmonitionInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl
    name_positional_attributes :text
    format :short

    def initialize(role, default_text)
      super(nil)
      @role = role
      @default_text = default_text
    end

    def process(parent, _target, attrs)
      text = attrs[:text]
      text ||= @default_text
      Asciidoctor::Inline.new(
        parent, :admonition, text, type: @role, attributes: {
          'title_type' => 'title',
          'title_class' => 'u-mono',
          'title' => @role,
        }
      )
    end
  end
end
