# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Extensions for marking something as `beta`, `dev`, or technical `preview`.
#
# Usage
#
#   beta::[]
#   dev::[]
#   preview::[]
#   Foo beta:[]
#   Foo dev:[]
#   Foo preview:[]
#
# !! `experimental:[]` is supported as a deprecated alternative to `preview:[]`.
# !! But please use `preview:[]` instead.
#
class CareAdmonition < Asciidoctor::Extensions::Group
  BETA_DEFAULT_TEXT = <<~TEXT.strip
    This functionality is in beta and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.
  TEXT
  DEV_DEFAULT_TEXT = <<~TEXT.strip
    This functionality is in development and may be changed or removed completely in a future release. These features are unsupported and not subject to the support SLA of official GA features.
  TEXT
  PREVIEW_DEFAULT_TEXT = <<~TEXT.strip
    This functionality is in technical preview and may be changed or removed in a future release. Elastic will apply best effort to fix any issues, but features in technical preview are not subject to the support SLA of official GA features.
  TEXT

  def activate(registry)
    [
      [:beta, 'Beta', BETA_DEFAULT_TEXT, ' stage-beta'],
      [:dev, 'In development', DEV_DEFAULT_TEXT , ' stage-dev'],
      [:experimental, 'Technical preview', PREVIEW_DEFAULT_TEXT, ' stage-preview'],
      [:preview, 'Technical preview', PREVIEW_DEFAULT_TEXT, ' stage-preview'],
    ].each do |(name, role, default_text, title_class)|
      registry.block_macro ChangeAdmonitionBlock.new(role, default_text), name
      registry.inline_macro ChangeAdmonitionInline.new(role, default_text, title_class), name
    end
  end

  ##
  # Block care admonition.
  class ChangeAdmonitionBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :passtext, :issue_url

    def initialize(role, default_text)
      super(nil)
      @role = role
      @default_text = default_text
    end

    def generate_text(text, issue_url)
      if text&.start_with?('http', '{issue}')
        issue_url = text
        text = @default_text
      else
        issue_url = issue_url
        text ||= @default_text
      end
      text = add_issue_text(text, issue_url) if issue_url
      text
    end

    def add_issue_text(text, issue_url)
      issue_num = get_issue_num(issue_url)
      issue_text = <<~TEXT
        For feature status, see #{issue_url}[\##{issue_num}].
      TEXT
      text + ' ' + issue_text
    end

    def get_issue_num(url)
      return url.split('/').last.chomp('/') if url.start_with?('http')

      url.sub('{issue}', '')
    end

    def process(parent, _target, attrs)
      text = generate_text(attrs[:passtext], attrs[:issue_url])
      Asciidoctor::Block.new(
        parent, :admonition, source: text, attributes: {
          'role' => @role,
          'name' => 'beaker',
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

    def initialize(role, default_text, extra_title_class)
      super(nil)
      @role = role
      @default_text = default_text
      @extra_title_class = extra_title_class
    end

    def process(parent, _target, attrs)
      text = attrs[:text]
      text ||= @default_text
      Asciidoctor::Inline.new(
        parent, :admonition, text, type: @role, attributes: {
          'title_type' => 'title',
          'title_class' => "#{@extra_title_class}",
          'title' => @role,
        }
      )
    end
  end
end
