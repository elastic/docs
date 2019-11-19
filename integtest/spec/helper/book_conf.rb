# frozen_string_literal: true

##
# Methods to build the config for a book.
module BookConf
  ##
  # The configuration needed to build the book.
  def conf
    # We can't use to_yaml here because it emits yaml 1.2 but the docs build
    # only supports 1.0.....
    yaml = standard_conf
    yaml += variable_conf
    yaml += <<~YAML
      sources:
      #{sources_conf}
    YAML
    indent yaml, '    '
  end

  private

  def standard_conf
    <<~YAML
      title:      #{@title}
      prefix:     #{@prefix}
      current:    #{@current_branch}
      branches:   [ #{@branches.join ', '} ]
      index:      #{@index}
      tags:       test tag
      subject:    Test
      lang:       #{@lang}
      direct_html: #{@direct_html}
    YAML
  end

  def variable_conf
    yaml = ''
    yaml += "noindex: 1\n" if @noindex
    yaml += "live: [ #{@live_branches.join ', '} ]\n" if @live_branches
    yaml += "respect_edit_url_overrides: true\n" if @respect_edit_url_overrides
    yaml += "suppress_migration_warnings: 1\n" if @suppress_migration_warnings
    yaml
  end

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
