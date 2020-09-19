# frozen_string_literal: true

require 'pathname'
require 'yaml'

require_relative 'book'
require_relative 'repo'

##
# Helper class for setting up source files for tests.
class Source
  attr_reader :books

  attr_accessor :toc_extra

  def initialize(tmp)
    @root = File.expand_path 'src', tmp
    Dir.mkdir @root
    @repos = Hash.new { |hash, name| hash[name] = Repo.new name, path(name) }
    @books = {}
    @toc_extra = nil
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
  # Create a new book and return it. The prefix should default to the title,
  # lowercased, with whitespace replaced with `-`.
  def book(title, prefix: title.downcase.gsub(/\s/, '-'))
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
  # Create a repo with an index.asciidoc file and a book that uses it as
  # a source.
  def book_and_repo(repo_name, book_name, index_content)
    repo = repo_with_index repo_name, index_content
    book(book_name).source repo, 'index.asciidoc'
  end

  ##
  # Create two repos and a book. The first repo contains an index that includes
  # a file in the second repo. The book is configured to use both repos as a
  # source so that it'll build properly.
  def simple_include
    book_and_repo 'repo1', 'Test', <<~ASCIIDOC
      Include between here
      include::../repo2/included.asciidoc[]
      and here.
    ASCIIDOC
    repo2 = repo_with_file 'repo2', 'included.asciidoc', 'included text'
    book('Test').source repo2, 'included.asciidoc'
  end

  ##
  # Build the config file that can build all books declared in this source.
  def conf(relative_path: false)
    path = write 'conf.yaml', build_conf
    return path unless relative_path

    Pathname.new(path)
            .relative_path_from(Pathname.new(Dir.getwd))
            .to_s
  end

  private

  def build_conf
    conf = {
      contents_title: 'Test',
      toc_extra: @toc_extra,
      repos: @repos.values.map { |repo| [repo.name, repo.root] }.to_h,
      contents: @books.values.map(&:conf),
    }.compact
    conf = desymbolize_keys conf
    conf.to_yaml
  end
end
