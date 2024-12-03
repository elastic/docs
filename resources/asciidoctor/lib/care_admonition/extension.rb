# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Extensions for marking something as `beta`, `beta_serverless`, `beta_ess`,
# `dev`, `dev_serverless`, `dev_ess`, technical `preview`, `preview_serverless`,
# `preview_ess`, `ga_serverless`, `ga_ess`.
#
# Usage
#
#   beta::[]
#   dev::[]
#   preview::[]
#   beta_ess::[]
#   beta_serverless::[]
#   dev_ess::[]
#   dev_serverless::[]
#   ga_serverless::[]
#   deprecated_ess::[]
#   deprecated_serverless::[]
#   discontinued_ess::[]
#   discontinued_serverless::[]
#   coming_ess::[]
#   coming_serverless::[]
#   Foo beta:[]
#   Foo dev:[]
#   Foo preview:[]
#   Foo beta_ess:[]
#   Foo beta_serverless:[]
#   Foo dev_ess:[]
#   Foo dev_serverless:[]
#   Foo preview_ess:[]
#   Foo preview_serverless:[]
#   Foo ga_ess:[]
#   Foo ga_serverless:[]
#   Foo deprecated_ess:[]
#   Foo deprecated_serverless:[]
#   Foo discontinued_ess:[]
#   Foo discontinued_serverless:[]
#   Foo coming_ess:[]
#   Foo coming_serverless::[]
#
# !! `experimental:[]` is supported as a deprecated alternative to `preview:[]`.
# !! But please use `preview:[]` instead.
#
class CareAdmonition < Asciidoctor::Extensions::Group
  BETA_DEFAULT_TEXT = <<~TEXT.strip
    This functionality is in beta and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.
  TEXT
  BETA_SERVERLESS_TEXT = <<~TEXT.strip
    This functionality is in beta in Elastic Cloud Serverless and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.
  TEXT
  BETA_ESS_TEXT = <<~TEXT.strip
    This functionality is in beta in Elasticsearch Service and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.
  TEXT
  DEV_DEFAULT_TEXT = <<~TEXT.strip
    This functionality is in development and may be changed or removed completely in a future release. These features are unsupported and not subject to the support SLA of official GA features.
  TEXT
  DEV_SERVERLESS_TEXT = <<~TEXT.strip
    This functionality is in development in Elastic Cloud Serverless and may be changed or removed completely in a future release. These features are unsupported and not subject to the support SLA of official GA features.
  TEXT
  DEV_ESS_TEXT = <<~TEXT.strip
    This functionality is in development in Elasticsearch Service and may be changed or removed completely in a future release. These features are unsupported and not subject to the support SLA of official GA features.
  TEXT
  PREVIEW_DEFAULT_TEXT = <<~TEXT.strip
    This functionality is in technical preview and may be changed or removed in a future release. Elastic will work to fix any issues, but features in technical preview are not subject to the support SLA of official GA features.
  TEXT
  PREVIEW_SERVERLESS_TEXT = <<~TEXT.strip
    This functionality is in technical preview in Elastic Cloud Serverless and may be changed or removed in a future release. Elastic will work to fix any issues, but features in technical preview are not subject to the support SLA of official GA features.
  TEXT
  PREVIEW_ESS_TEXT = <<~TEXT.strip
    This functionality is in technical in preview in Elasticsearch Service and may be changed or removed in a future release. Elastic will work to fix any issues, but features in technical preview are not subject to the support SLA of official GA features.
  TEXT
  DEPRECATED_ESS_TEXT = <<~TEXT.strip
    This functionality is deprecated in Elasticsearch Service and will be removed in a future release.
  TEXT
  DEPRECATED_SERVERLESS_TEXT = <<~TEXT.strip
    This functionality is deprecated in Elastic Cloud Serverless and will be removed in a future release.
  TEXT
  DISCONTINUED_ESS_TEXT = <<~TEXT.strip
    This functionality is discontinued in Elasticsearch Service.
  TEXT
  DISCONTINUED_SERVERLESS_TEXT = <<~TEXT.strip
    This functionality is discontinued in Elastic Cloud Serverless.
  TEXT
  COMING_ESS_TEXT = <<~TEXT.strip
    This functionality is coming in Elasticsearch Service.
  TEXT
  COMING_SERVERLESS_TEXT = <<~TEXT.strip
    This functionality is coming in Elastic Cloud Serverless.
  TEXT
  GA_ESS_TEXT = <<~TEXT.strip
    This functionality is generally available in Elasticsearch Service.
  TEXT
  GA_SERVERLESS_TEXT = <<~TEXT.strip
    This functionality is generally available in Elastic Cloud Serverless.
  TEXT

  def activate(registry)
    [
      [:beta, 'Beta', 'beta', BETA_DEFAULT_TEXT],
      [:beta_serverless, 'Serverless: Beta', 'serverless_beta', BETA_SERVERLESS_TEXT],
      [:beta_ess, 'ESS: Beta', 'ess_beta', BETA_ESS_TEXT],
      [:dev, 'dev', 'dev', DEV_DEFAULT_TEXT],
      [:dev_serverless, 'Serverless: Dev', 'serverless_dev', DEV_SERVERLESS_TEXT],
      [:dev_ess, 'ESS: Dev', 'ess_dev', DEV_ESS_TEXT],
      [:experimental, 'preview', 'preview', PREVIEW_DEFAULT_TEXT],
      [:preview, 'Preview', 'preview', PREVIEW_DEFAULT_TEXT],
      [:preview_serverless, 'Serverless: Preview', 'serverless_preview', PREVIEW_SERVERLESS_TEXT],
      [:preview_ess, 'ESS: Preview', 'ess_preview', PREVIEW_ESS_TEXT],
      [
        :deprecated_serverless,
        'Serverless: Deprecated',
        'serverless_deprecated',
        DEPRECATED_SERVERLESS_TEXT,
      ],
      [:deprecated_ess, 'ESS: Deprecated', 'hello', DEPRECATED_ESS_TEXT],
      [
        :discontinued_serverless,
        'Serverless: Removed',
        'serverless_removed',
        DISCONTINUED_SERVERLESS_TEXT,
      ],
      [:discontinued_ess, 'ESS: Removed', 'ess_removed', DISCONTINUED_ESS_TEXT],
      [:coming_serverless, 'Serverless: Coming soon', 'serverless_coming', COMING_SERVERLESS_TEXT],
      [:coming_ess, 'ESS: Coming soon', 'ess_coming', COMING_ESS_TEXT],
      [:ga_serverless, 'Serverless: GA', 'serverless_ga', GA_SERVERLESS_TEXT],
      [:ga_ess, 'ESS: GA', 'ess_ga', GA_ESS_TEXT],
      [:serverless_available, 'Serverless', 'serverless_available', GA_SERVERLESS_TEXT],
      [:ess_available, 'ESS', 'ess_available', GA_ESS_TEXT],
      [:serverless_unavailable, 'Serverless', 'serverless_unavailable', 'This functionality is not available in Elastic Cloud Serverless.'],
      [:ess_unavailable, 'ESS', 'ess_unavailable', 'This functionality is not available in Elasticsearch Service.'],
    ].each do |(name, role, classname,  default_text)|
      registry.block_macro ChangeAdmonitionBlock.new(role, classname, default_text), name
      registry.inline_macro ChangeAdmonitionInline.new(role, classname, default_text), name
    end
  end

  ##
  # Block care admonition.
  class ChangeAdmonitionBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :passtext, :issue_url

    def initialize(role, classname, default_text)
      super(nil)
      @role = role
      @classname = classname
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

    def initialize(role, classname, default_text)
      super(nil)
      @role = role
      @classname = 'Admonishment--' + classname
      @default_text = default_text
    end

    def process(parent, _target, attrs)
      text = attrs[:text]
      text ||= @default_text
      Asciidoctor::Inline.new(
        parent, :admonition, text, type: @role, attributes: {
          'title_type' => 'title',
          'title_class' => @classname,
          'title' => @role,
        }
      )
    end
  end
end
