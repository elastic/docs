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
      return unless File.exist? file

      File.open(dest_file(file), 'r:UTF-8') do |f|
        f.read
         .sub(/.+<!-- start body -->/m, '')
         .sub(/<!-- end body -->.+/m, '')
      end
    end
    let(:title) do
      return unless body

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
  # to convert. It does the conversion with both with `--asciidoctor` and
  # without `--asciidoctor` and asserts that the files are the same.
  def convert_single_before_context
    include_context 'tmp dirs'
    before(:context) do
      from = yield(Source.new @src)
      @asciidoctor_out = convert_single from, @dest,
                                        asciidoctor: true
      @asciidoc_out = convert_single from, "#{@dest}/asciidoc",
                                     asciidoctor: false
    end
    include_examples 'convert single'
  end
  shared_context 'convert single' do
    let(:out) { @asciidoctor_out }
    let(:asciidoctor_files) do
      files_in(dest_file('.')).reject { |f| f.start_with? 'asciidoc/' }
    end
    let(:asciidoc_files) do
      files_in(dest_file('asciidoc'))
    end
    it 'prints the path to the html index' do
      expect(out).to include(dest_file('index.html'))
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
    it 'logs the same lines with asciidoc' do
      # The only difference should be that the output path includes `asciidoc/`
      expect(@asciidoc_out.gsub('asciidoc/', '')).to eq(@asciidoctor_out)
    end
    it 'makes the same files with asciidoc' do
      expect(asciidoc_files).to eq(asciidoctor_files)
    end
    it 'makes exactly the same html files with asciidoc' do
      # This does *all* the files in the same example which doesn't feel very
      # rspec but it gets the job done and we don't know the file list at this
      # point so there isn't much we can do about it.
      asciidoctor_files.each do |file|
        next unless File.extname(file) == '.html'

        # We shell out to the html_diff tool that we wrote for this when the
        # integration tests were all defined in a Makefile. It isn't great to
        # shell out here but we've already customized html_diff.
        asciidoctor_file = dest_file(file)
        asciidoc_file = dest_file("asciidoc/#{file}")
        html_diff = File.expand_path '../../html_diff', __dir__
        sh "#{html_diff} #{asciidoctor_file} #{asciidoc_file}"
      end
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
