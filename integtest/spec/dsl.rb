# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

module Dsl
  ##
  # Create a context to assert things about an html page. By default it just
  # asserts that the page was created but if you pass a block you can add
  # assertions on `body` and `title`.
  def page_context(file_name, &block)
    context "for #{file_name}" do
      let(:file) do
        dest_file(file_name)
      end
      let(:body) do
        return nil unless File.exist? file

        File.open(dest_file(file), 'r:UTF-8') do |f|
          f.read
           .sub(/.+<!-- start body -->/m, '')
           .sub(/<!-- end body -->.+/m, '')
        end
      end
      let(:title) do
        return nil unless body

        m = body.match(
          %r{<h1 class="title"><a id=".+"></a>([^<]+)(<a.+?)?</h1>}
        )
        raise "Can't find title in #{body}" unless m

        m[1]
      end

      it 'is created' do
        expect(file).to file_exist
      end
      # Yield to the block to more tests.
      class_exec(&block)
    end
  end
end

# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
