# frozen_string_literal: true

require_relative 'book_conf'

class Book
  include BookConf
  attr_reader :title, :prefix

  ##
  # Set the index file for the book. If this isn't called the default
  # is `index.asciidoc`.
  attr_writer :index

  ##
  # The list of branches to build
  attr_accessor :branches

  ##
  # The branch that is marked "current"
  attr_accessor :current_branch

  ##
  # Should this book allow overriding :edit_url:? Defaults to false.
  attr_accessor :respect_edit_url_overrides

  ##
  # The language of the book. Defaults to `en`.
  attr_accessor :lang

  ##
  # Should this book suppress all migration warnings, even in the newest
  # version? Defaults to false.
  attr_accessor :suppress_migration_warnings

  ##
  # Should this book built directly to html (true) or to docbook first (false).
  attr_accessor :direct_html

  ##
  # Should the book declare itself noindex? Defaults to false.
  attr_accessor :noindex

  ##
  # List of branches that are considered "live" for a book. Branches that are
  # not live will be marked as `noindex`. Defaults to nil, meaning don't emit
  # the list of live branches. In that case the docs build will default to
  # *all* branches being live.
  attr_accessor :live_branches

  ##
  # Is the book a single page book?
  attr_accessor :single

  ##
  # Path to extra html to write into the book's table of contents.
  attr_accessor :toc_extra

  def initialize(title, prefix)
    @title = title
    @prefix = prefix
    @index = 'index.asciidoc'
    @sources = []
    @branches = ['master']
    @current_branch = 'master'
    @lang = 'en'
    @respect_edit_url_overrides = @suppress_migration_warnings = false
    @direct_html = @noindex = @single = false
    @live_branches = @toc_extra = nil
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
  # The html for a link to a particular branch of this book.
  def link_to(branch)
    url = "#{@prefix}/#{branch}/index.html"
    decoration = ''
    if branch == 'current' && @branches.length != 1
      decoration = " [#{@current_branch}]"
    end
    %(<a class="ulink" href="#{url}" target="_top">#{@title}#{decoration}</a>)
  end
end
