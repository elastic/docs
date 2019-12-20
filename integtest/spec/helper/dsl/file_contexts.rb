# frozen_string_literal: true

require 'json'

module Dsl
  ##
  # Methods to create contexts for asserting things about files and
  # their contents.
  module FileContexts
    ##
    # Create a context to assert things about an html page. By default it just
    # asserts that the page was created but if you pass a block you can add
    # assertions on `contents, `body`, and `title`.
    def page_context(name, file_name = name, &block)
      context "for #{name}" do
        include_context 'Dsl_page', file_name

        # Yield to the block to add more tests.
        class_exec(&block) if block
      end
    end
    shared_context 'Dsl_page' do |file_name|
      include_context 'Dsl_file', file_name
      let(:head) do
        return unless contents

        contents.sub(/.+<head>/m, '').sub(%r{</head>.+}m, '')
      end
      let(:head_title) do
        m = head&.match %r{<title>(.+?)</title>}m
        raise "can't find title in #{head}" unless m

        m[1]
      end
      let(:body) do
        return unless contents

        contents.sub(/.+<!-- start body -->/m, '')
                .sub(/<!-- end body -->.+/m, '')
      end
      let(:title) do
        return unless body

        m = body.match(
          %r{<h\d class="title"><a id="[^"]+"></a>([^<]+)(<a.+?)?</h\d>}
        )
        raise "Can't find title in #{body}" unless m

        m[1]
      end
      let(:language) do
        return unless contents

        m = contents.match(/<section id="guide" lang="([^"]+)">/)
        raise "Can't find language in #{contents}" unless m

        m[1]
      end
    end
  end
end
