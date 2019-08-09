# frozen_string_literal: true

class Book
  attr_reader :title, :prefix

  ##
  # Set the index file for the book. If this isn't called the default
  # is `index.asciidoc`.
  attr_writer :index

  ##
  # Should this book build with asciidoctor (true) or asciidoc (false).
  attr_accessor :asciidoctor

  ##
  # The list of branches to build
  attr_accessor :branches

  ##
  # Should this book allow overriding :edit_url:? Defaults to false.
  attr_accessor :respect_edit_url_overrides

  def initialize(title, prefix)
    @title = title
    @prefix = prefix
    @index = 'index.asciidoc'
    @asciidoctor = true
    @sources = []
    @branches = ['master']
    @respect_edit_url_overrides = false
  end

  ##
  # Define a source repository for the book. Calling this again with the same
  # repo will redefine the source for that repo.
  # repo - the repository containing the source files
  # path - path within the repository to checkout to build the book
  # map_branches - optional hash that overrides which branch is used for this
  #                repo when the book is building a particular branch
  # is_private - Configure the source to be private so it doesn't get edit
  #              urls. Defaults to false.
  # alternatives - Marks this source as a source of alternative examples. Must
  #                be a hash containing :source_lang and :alternative_lang.
  def source(repo, path,
             map_branches: nil, is_private: false, alternatives: nil)
    @sources.push(
      repo: repo.name,
      path: path,
      map_branches: map_branches,
      is_private: is_private,
      alternatives: alternatives
    )
  end

  ##
  # The configuration needed to build the book.
  def conf
    # We can't use to_yaml here because it emits yaml 1.2 but the docs build
    # only supports 1.0.....
    conf = standard_conf
    conf += "respect_edit_url_overrides: true\n" if @respect_edit_url_overrides
    conf += <<~YAML
      sources:
      #{sources_conf}
    YAML
    indent conf, '    '
  end

  def standard_conf
    <<~YAML
      title:      #{@title}
      prefix:     #{@prefix}
      current:    master
      branches:   [ #{@branches.join ', '} ]
      index:      #{@index}
      tags:       test tag
      subject:    Test
      asciidoctor: #{@asciidoctor}
    YAML
  end

  ##
  # The html for a link to a particular branch of this book.
  def link_to(branch)
    url = "#{@prefix}/#{branch}/index.html"
    decoration = ''
    decoration = ' [master]' unless @branches.length == 1
    %(<a class="ulink" href="#{url}" target="_top">#{@title}#{decoration}</a>)
  end

  private

  def sources_conf
    yaml = ''
    @sources.each do |config|
      yaml += "\n-\n#{source_conf config}"
    end
    indent yaml, '  '
  end

  def source_conf(config)
    yaml = <<~YAML
      repo:    #{config[:repo]}
      path:    #{config[:path]}
    YAML
    yaml += alternatives_conf config[:alternatives]
    yaml += "private: true\n" if config[:is_private]
    yaml += map_branches_conf config[:map_branches]
    indent yaml, '  '
  end

  def alternatives_conf(conf)
    return '' unless conf

    yaml = ''
    yaml += "alternatives:\n"
    yaml += "  source_lang: #{conf[:source_lang]}\n"
    yaml += "  alternative_lang: #{conf[:alternative_lang]}\n"
    yaml
  end

  def map_branches_conf(map_branches)
    return '' unless map_branches

    yaml = "map_branches:\n"
    map_branches.each_pair do |key, value|
      yaml += "  #{key}: #{value}\n"
    end
    yaml
  end
end
