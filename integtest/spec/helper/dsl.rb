# frozen_string_literal: true

##
# Defines methods to create contexts for converting asciidoc files to html.
module Dsl
  ##
  # Create a context to assert things about an html page. By default it just
  # asserts that the page was created but if you pass a block you can add
  # assertions on `body` and `title`.
  def page_context(file_name, &block)
    context "for #{file_name}" do
      include_context 'page', file_name

      # Yield to the block to add more tests.
      class_exec(&block)
    end
  end
  shared_context 'page' do |file_name|
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

      m = body.match %r{<h1 class="title"><a id=".+"></a>([^<]+)(<a.+?)?</h1>}
      raise "Can't find title in #{body}" unless m

      m[1]
    end

    it 'is created' do
      expect(file).to file_exist
    end
  end

  ##
  # Include a context into the current context that converts asciidoc files
  # into html and adds some basic assertions about the conversion process. Pass
  # a block that takes a `Source` object and returns the "root" asciidoc file
  # to convert.
  def convert_single_before_context
    include_context 'tmp dirs'
    before(:context) do
      from = yield(Source.new @src)
      @out = convert_single from, @dest
    end
    include_examples 'convert single'
  end
  shared_context 'convert single' do
    let(:out) { @out }
    it 'prints the path to the html index' do
      expect(out).to include("#{@dest}/index.html")
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
