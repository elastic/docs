# frozen_string_literal: true

RSpec.describe 'building a single book' do
  ##
  # Builds a path to afile in the source.
  def source_file(file)
    File.expand_path(file, @src)
  end

  ##
  # Write a source file.
  def write_source(source_path, text)
    path = source_file source_path
    File.open(path, 'w:UTF-8') do |f|
      f.write text
    end
    path
  end

  ##
  # Init a git repo in root and commit any files in it.
  def init_repo(root)
    Dir.chdir root do
      sh 'git init'
      sh 'git add .'
      sh "git commit -m 'init'"
      # Add an Elastic remote so we get a nice edit url
      sh 'git remote add elastic git@github.com:elastic/docs.git'
    end
  end

  def convert_args(from, to)
    %W[
      --doc #{from}
      --out #{to}
    ]
  end

  ##
  # Context for converting asciidoc files into html. To use this include it in
  # a context and then define a `make_input` method that initializes the source
  # files and returns the path of the "index" asciidoc file, preferably
  # using `write_source`.
  shared_context 'convert' do
    include_context 'tmp dirs'
    before(:context) do
      from = make_input
      init_repo(File.expand_path('..', from))
      # Use popen here instead of capture to keep stdin open to appease the
      # docker-image-always-removed paranoia in build_docs.pl
      _stdin, out, wait_thr = Open3.popen2e(
        '/docs_build/build_docs.pl', '--in_standard_docker',
        *convert_args(from, @dest)
      )
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

  HEADER = <<~ASCIIDOC
    = Title

    [[chapter]]
    == Chapter
  ASCIIDOC

  context 'for a minimal book' do
    shared_context 'expected' do
      def make_input
        write_source file_name, <<~ASCIIDOC
          #{HEADER}
          This is a minimal viable asciidoc file for use with build_docs. The
          actual contents of this paragraph aren't important but having a
          paragraph here is required.
        ASCIIDOC
      end
      include_context 'convert'

      page_context 'index.html' do
        it 'has the right title' do
          expect(title).to eq('Title')
        end
      end
      page_context 'chapter.html' do
        it 'has the right title' do
          expect(title).to eq('Chapter')
        end
      end
    end

    context 'when the file ends in .asciidoc' do
      def file_name
        'minimal.asciidoc'
      end
      include_context 'expected', 'minimal.asciidoc'
    end

    context 'when the file ends in .adoc' do
      def file_name
        'minimal.adoc'
      end
      include_context 'expected', 'minimal.adoc'
    end
  end

  context 'when one file includes another' do
    def make_input
      write_source 'included.asciidoc', 'I am tiny.'
      write_source 'index.asciidoc', <<~ASCIIDOC
        #{HEADER}
        I include "included" between here

        include::included.asciidoc[]

        and here.
      ASCIIDOC
    end
    include_context 'convert'

    page_context 'chapter.html' do
      it 'contains the index text' do
        expect(body).to include('I include "included"')
      end
      it 'contains the included text' do
        expect(body).to include('I am tiny.')
      end
    end
  end
  context 'when the book contains beta[]' do
    def make_input
      write_source 'index.asciidoc', <<~ASCIIDOC
        #{HEADER}
        beta[]

        Words
      ASCIIDOC
    end
    include_context 'convert'

    it 'copies the warning image' do
      expect(dest_file('images/icons/warning.png')).to file_exist
    end
    page_context 'chapter.html' do
      it 'includes the warning image' do
        expect(body).to include(
          '<img alt="Warning" src="images/icons/warning.png" />'
        )
      end
      it 'includes the beta text' do
        expect(body).to include(
          'The design and code is less mature than official GA features'
        )
      end
    end
  end
end
