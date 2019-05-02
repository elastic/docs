# frozen_string_literal: true

require_relative 'book'
require_relative 'repo'

##
# Helper class for setting up source files for tests.
class Source
  attr_reader :books

  def initialize(tmp)
    @root = File.expand_path 'src', tmp
    Dir.mkdir @root
    @repos = []
    @books = []
  end

  ##
  # Create a source repo and return it. You should add files to be converted.
  def repo(name)
    Repo.new(name, path(name)).tap { |r| @repos.push r }
  end

  ##
  # Create a repository with an index file.
  def simple_repo(name, index_content)
    repo(name).tap do |repo|
      repo.write 'index.asciidoc', <<~ASCIIDOC
        = Title

        [[chapter]]
        == Chapter
        #{index_content}
      ASCIIDOC
      repo.commit 'init'
    end
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
  def book(title, prefix)
    Book.new(title, prefix).tap { |b| @books.push b }
  end

  ##
  # Create a book and initialize the provided repo as one of its sources.
  def simple_book(repo)
    book('Test', 'test').tap do |book|
      book.source repo, 'index.asciidoc'
    end
  end

  ##
  # Build the config file that can build all books declared in this source.
  def conf
    # We can't use to_yaml here because it emits yaml 1.2 but the docs build
    # only supports 1.0.....
    write 'conf.yaml', <<~YAML
      #{common_conf}
      repos:#{repos_conf}
      contents:#{books_conf}
    YAML
  end

  private

  def common_conf
    repos_path = path '../repos' # TODO: .. is pretty lame here
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
    @repos.each do |repo|
      repos_yaml += "\n  #{repo.name}: #{repo.root}"
    end
    repos_yaml
  end

  def books_conf
    books_yaml = ''
    @books.each do |book|
      books_yaml += "\n  -\n"
      books_yaml += book.conf
    end
    books_yaml
  end
end
