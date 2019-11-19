# frozen_string_literal: true

##
# Methods to build the config for a book.
module BookConf
  ##
  # The configuration needed to build the book.
  def conf
    conf = basic_conf
    conf.merge! branches_conf
    conf.merge! flags_conf
    conf[:sources] = @sources.map { |source| source_conf source }
    conf.compact
  end

  private

  def basic_conf
    {
      title: @title,
      prefix: @prefix,
      index: @index,
      lang: @lang,
      tags: 'test tag',
      subject: 'Test',
    }
  end

  def source_conf(source)
    {
      repo: source[:repo],
      path: source[:path],
      private: source[:is_private] ? true : nil,
      map_branches: source[:map_branches],
      alternatives: source[:alternatives],
    }.compact
  end

  def branches_conf
    {
      current: @current_branch,
      branches: @branches,
      live: @live_branches,
    }
  end

  ##
  # Config for "flags" on the book. Some are "perl style" and take "1" when
  # true. Others are "normal style" and take "true" when "true". Either way,
  # when they are false we leave them out entirely.
  def flags_conf
    {
      noindex: @noindex ? 1 : nil,
      direct_html: @direct_html ? true : nil,
      respect_edit_url_overrides: @respect_edit_url_overrides ? true : nil,
      suppress_migration_warnings: @suppress_migration_warnings ? 1 : nil,
    }
  end
end
