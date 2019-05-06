# frozen_string_literal: true

class Book
  attr_reader :title, :prefix

  ##
  # Set the index file for the book. If this isn't called the default
  # is `index.asciidoc`.
  attr_writer :index

  def initialize(title, prefix)
    @title = title
    @prefix = prefix
    @index = 'index.asciidoc'
    @sources = {}
  end

  ##
  # Define a source repository for the book. Calling this again with the same
  # repo will redefine the source for that repo.
  # repo - the repository containing the source files
  # path - path within the repository to checkout to build the book
  # map_branches - optional hash that overrides which branch is used for this
  #                repo when the book is building a particular branch
  def source(repo, path, map_branches: nil)
    @sources[repo.name] = { path: path, map_branches: map_branches }
  end

  ##
  # The configuration needed to build the book.
  def conf
    # We can't use to_yaml here because it emits yaml 1.2 but the docs build
    # only supports 1.0.....
    <<~YAML.split("\n").map { |s| '    ' + s }.join "\n"
      title:      #{@title}
      prefix:     #{@prefix}
      current:    master
      branches:   [ master ]
      index:      #{@index}
      tags:       test tag
      subject:    Test
      asciidoctor: true
      sources:
      #{sources_conf}
    YAML
  end

  ##
  # The html for a link to a particular branch of this book.
  def link_to(branch)
    url = "#{@prefix}/#{branch}/index.html"
    %(<a class="ulink" href="#{url}" target="_top">#{@title}</a>)
  end

  private

  def sources_conf
    yaml = ''
    @sources.each_pair do |repo_name, config|
      yaml += <<~YAML
        -
          repo:   #{repo_name}
          path:   #{config[:path]}
      YAML
      yaml += map_branches_conf config[:map_branches]
    end
    yaml.split("\n").map { |s| '  ' + s }.join "\n"
  end

  def map_branches_conf(map_branches)
    return '' unless map_branches

    yaml = "  map_branches:\n"
    map_branches.each_pair do |key, value|
      yaml += "    #{key}: #{value}\n"
    end
    yaml
  end
end
