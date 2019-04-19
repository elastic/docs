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
    @sources = []
  end

  ##
  # Define a source repository for the book.
  # repo - the repository containing the source files
  # path - path within the repository to checkout to build the book
  def source(repo, path)
    @sources.push repo: repo, path: path
  end

  ##
  # The configuration needed to build the book.
  def conf
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

  def link_to(branch)
    url = "#{@prefix}/#{branch}/index.html"
    %(<a class="ulink" href="#{url}" target="_top">#{@title}</a>)
  end

  private

  def sources_conf
    sources_yaml = ''
    @sources.each do |source|
      sources_yaml += <<~YAML
        -
          repo:   #{source[:repo].name}
          path:   #{source[:path]}
      YAML
    end
    sources_yaml.split("\n").map { |s| '  ' + s }.join "\n"
  end
end
