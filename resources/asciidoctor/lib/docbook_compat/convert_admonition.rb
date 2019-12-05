# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert admonitions.
  module ConvertAdmonition
    def convert_admonition(node)
      content = admonition_content node
      [
        %(<div class="#{node.attr 'name'} admon">),
        %(<div class="icon"></div>),
        %(<div class="admon_content">),
        node.title? ? "<h3>#{node.title}</h3>" : nil,
        node.blocks.empty? ? "<p>#{content}</p>" : content,
        '</div>',
        '</div>',
      ].compact.join "\n"
    end

    private

    ADMONITION_DEFAULT_MESSAGE = {
      'beta' => <<~TEXT.strip,
        This functionality is in beta and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features.
      TEXT
      'experimental' => <<~TEXT.strip,
        This functionality is experimental and may be changed or removed completely in a future release. Elastic will take a best effort approach to fix any issues, but experimental features are not subject to the support SLA of official GA features.
      TEXT
    }.freeze
    def admonition_content(node)
      content = node.content
      return content unless content == ''

      ADMONITION_DEFAULT_MESSAGE[node.role]
    end
  end
end
