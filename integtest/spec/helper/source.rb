# frozen_string_literal: true

require 'pathname'

require_relative 'book'
require_relative 'repo'

##
# Helper class for setting up source files for tests.
class Source
  attr_reader :books

  def initialize(tmp)
    @root = File.expand_path 'src', tmp
    Dir.mkdir @root
    @repos = Hash.new { |hash, name| hash[name] = Repo.new name, path(name) }
    @books = {}
  end

  ##
  # Create a source repo and return it. You should add files to be converted.
  def repo(name)
    @repos[name]
  end

  ##
  # Write a source file and return the absolute path to that file.
  def write(source_relative_path, text)
    realpath = path source_relative_path
    dir = File.expand_path '..', realpath
    FileUtils.mkdir_p dir
    File.open(realpath, 'w:UTF-8') do |f|
      f.write text
    end
    realpath
  end

  ##
  # Transform path fragment for a source file into the path that that file
  # should have.
  def path(source_relative_path)
    File.expand_path(source_relative_path, @root)
  end

  ##
  # Create a new book and return it.
  def book(title, prefix: title.downcase)
    @books[title] || (@books[title] = Book.new title, prefix)
  end

  ##
  # Create a repository containing a file and commit that. Returns the repo.
  def repo_with_file(name, file, content)
    repo(name).tap do |repo|
      repo.write file, content
      repo.commit 'init'
    end
  end

  ##
  # Create a repository with an index file that includes headings that make
  # docbook happy and commit that file. Returns the repo.
  def repo_with_index(name, index_content)
    repo_with_file name, 'index.asciidoc', <<~ASCIIDOC
      = Title

      [[chapter]]
      == Chapter
      #{index_content}
    ASCIIDOC
  end

  ##
  # Create two repos and a book. The first repo contains an index that includes
  # a file in the second repo. The book is configured to use both repos as a
  # source so that it'll build properly.
  def simple_include
    repo1 = repo_with_index 'repo1', <<~ASCIIDOC
      Include between here
      include::../repo2/included.asciidoc[]
      and here.
    ASCIIDOC
    repo2 = repo_with_file 'repo2', 'included.asciidoc', 'included text'
    book = book 'Test'
    book.source repo1, 'index.asciidoc'
    book.source repo2, 'included.asciidoc'
  end

  ##
  # Build the config file that can build all books declared in this source.
  def conf(relative_path: false)
    # We can't use to_yaml here because it emits yaml 1.2 but the docs build
    # only supports 1.0.....
    path = write 'conf.yaml', <<~YAML
      #{common_conf}
      repos:#{repos_conf}
      contents:#{books_conf}
    YAML
    return path unless relative_path

    Pathname.new(path)
            .relative_path_from(Pathname.new(Dir.getwd))
            .to_s
  end

  private

  def common_conf
    repos_path = path '../repos'
    <<~YAML
      template:
        defaults:
          POSTHEAD: |
            <link rel="stylesheet" type="text/css" href="styles.css" />
          FINAL: |
            <script type="text/javascript" src="docs.js"></script>
            <script type='text/javascript' src='https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js?lang=yaml'></script>
      paths:
        build:          html/
        branch_tracker: html/branches.yaml
        repos:          #{repos_path}
      contents_title: Test
    YAML
  end

  def repos_conf
    repos_yaml = ''
    @repos.each_value do |repo|
      repos_yaml += "\n  #{repo.name}: #{repo.root}"
    end
    repos_yaml
  end

  def books_conf
    books_yaml = ''
    @books.each_value do |book|
      books_yaml += "\n  -\n"
      books_yaml += book.conf
    end
    books_yaml
  end
end
