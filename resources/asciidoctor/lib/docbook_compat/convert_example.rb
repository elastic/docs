# frozen_string_literal: true

module DocbookCompat
  ##
  # Methods to convert example blocks.
  module ConvertExample
    def convert_example(node)
      return yield unless node.title

      [
        '<div class="example">',
        %(<p class="title"><strong>#{node.captioned_title}</strong></p>),
        '<div class="example-contents">',
        node.content,
        '</div>',
        '</div>',
      ].compact.join "\n"
    end
  end
end
