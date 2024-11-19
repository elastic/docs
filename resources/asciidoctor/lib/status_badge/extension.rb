# frozen_string_literal: true

require 'asciidoctor/extensions'

class StatusBadge < Asciidoctor::Extensions::Group
  def activate(registry)
    registry.inline_macro StatusBadgeInline.new(), :status_badge
  end

  class StatusBadgeInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl
    name_positional_attributes :deployment_type, :availability, :version

    def initialize()
      super(nil)
    end

    def generate_tooltip_text(deployment_type, availability_type, version)
      # Deployment type
      if deployment_type == 'serverless'
        deployment_long_name = 'Elastic Cloud Serverless'
      elsif deployment_type == 'hosted'
        deployment_long_name = 'Elastic Cloud Hosted'
      elsif deployment_type == 'stack'
        deployment_long_name = 'Elastic Stack'
      elsif deployment_type == 'cloud'
        deployment_long_name = 'Elastic Cloud'
      elsif deployment_type == 'ece'
        deployment_long_name = 'Elastic Cloud Enterprise'
      elsif deployment_type == 'eck'
        deployment_long_name = 'Elastic Cloud Kubernetes'
      elsif deployment_type == 'self_managed'
        deployment_long_name = 'Self-managed'
      end

      # Availability
      if availability_type == 'preview'
        availability_tooltip_text = ' is in technical preview'
        availability_long_description = 'This functionality may be changed or removed in a future release. Elastic will work to fix any issues, but features in technical preview are not subject to the support SLA of official GA features.'
      elsif availability_type == 'beta'
        availability_tooltip_text = ' is in beta'
        availability_long_description = 'This functionality is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.'
      elsif availability_type == 'ga'
        availability_tooltip_text = ' is generally available'
        availability_long_description = ''
      elsif availability_type == 'coming'
        availability_tooltip_text = ' is coming soon'
        availability_long_description = 'This functionality is expected in an upcoming version, but is not guaranteed.'
      elsif availability_type == 'deprecated'
        availability_tooltip_text = ' is deprecated'
        availability_long_description = 'This will be removed in a future release.'
      elsif availability_type == 'discontinued'
        availability_tooltip_text = ' was discontinued'
        availability_long_description = ''
      elsif availability_type == 'unavailable'
        availability_tooltip_text = ' is unavailable'
        availability_long_description = ''
      else
        availability_tooltip_text = ' is available'
        availability_long_description = ''
      end

      text = 'This functionality'
      text += availability_tooltip_text
      text += ' in '
      text += deployment_long_name
      if version
        text += ' starting in '
        text += version
      end
      text += '. '
      text += availability_long_description
      text
    end

    def generate_badge_text(deployment_type, availability_type, version)
      # Deployment/product type
      if deployment_type == 'serverless'
        deployment_short_name = 'Serverless'
      elsif deployment_type == 'hosted'
        deployment_short_name = 'Hosted'
      elsif deployment_type == 'stack'
        deployment_short_name = 'Elastic Stack'
      elsif deployment_type == 'cloud'
        deployment_short_name = 'Elastic Cloud'
      elsif deployment_type == 'ece'
        deployment_short_name = 'ECE'
      elsif deployment_type == 'eck'
        deployment_short_name = 'ECK'
      elsif deployment_type == 'self_managed'
        deployment_short_name = 'Self-managed'
      end

      # Availability
      if availability_type == 'preview'
        availability_badge_text = 'Technical preview'
      elsif availability_type == 'beta'
        availability_badge_text = 'Beta'
      # elsif availability_type == 'ga'
      #   availability_badge_text = ''
      elsif availability_type == 'coming'
        availability_badge_text = 'Coming soon'
      elsif availability_type == 'deprecated'
        availability_badge_text = 'Deprecated'
      elsif availability_type == 'discontinued'
        availability_badge_text = 'Discontinued'
      elsif availability_type == 'unavailable'
        availability_badge_text
      end

      text = deployment_short_name
      if availability_badge_text
        text += ': '
        text += availability_badge_text
      end
      if version
        text += ' ('
        text += version
        text += ')'
      end
      text
    end

    def process(parent, _target, attrs)
      badge_text = generate_badge_text(attrs[:deployment_type], attrs[:availability], attrs[:version])
      text = generate_tooltip_text(attrs[:deployment_type], attrs[:availability], attrs[:version])
      classes = ' Admonishment--' + attrs[:deployment_type]
      tooltip_id = 'tooltip--'
      tooltip_id += attrs[:deployment_type]
      if attrs[:availability]
        classes += ' Admonishment--' +  attrs[:availability]
        tooltip_id += '_' + attrs[:availability]
      end
      if attrs[:version]
        tooltip_id += '_' + attrs[:version]
      end
      Asciidoctor::Inline.new(
        parent, :admonition, text, type: :status_badge, attributes: {
          'title_type' => 'title',
          'title_class' => classes,
          'title' => badge_text,
          'tooltip_id' => tooltip_id
        }
      )
    end
  end
end