# frozen_string_literal: true

require 'open3'

##
# Defines methods to create contexts for converting asciidoc files to html.
module Dsl
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

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
      # Yield to the block to add more tests.
      class_exec(&block)
    end
  end

  ##
  # Include a context that converts asciidoc files into html. Pass a block that
  # takes a `Source` object and returns the "root" asciidoc file to convert.
  def convert_single_before_context
    include_context 'tmp dirs'
    before(:context) do
      from = yield(Source.new @src)
      init_repo File.expand_path('..', from)
      cmd = ['/docs_build/build_docs.pl', '--in_standard_docker']
      cmd += convert_args(from, @dest)
      # Use popen here instead of capture to keep stdin open to appease the
      # docker-image-always-removed paranoia in build_docs.pl
      _stdin, out, wait_thr = Open3.popen2e(*cmd)
      status = wait_thr.value
      raise_status cmd, out, status unless status.success?

      out
    end
    it 'creates the template hash' do
      expect(dest_file('template.md5')).to file_exist
    end
    it 'creates the css' do
      expect(dest_file('styles.css')).to file_exist
    end
    it 'creates the js' do
      expect(dest_file('docs.js')).to file_exist
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  class Source
    def initialize(root)
      @root = root
    end

    ##
    # Write a source file and return the absolute path to that file.
    def write(path, text)
      path = "#{@root}/#{path}"
      File.open(path, 'w:UTF-8') do |f|
        f.write text
      end
      path
    end
  end
end
