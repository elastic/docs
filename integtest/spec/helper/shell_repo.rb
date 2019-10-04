# frozen_string_literal: true

require 'fileutils'

require_relative 'sh'

##
# Creates a repository with fonts in it so we don't have to add them over and
# over and over and over again.
module ShellRepo
  extend Sh

  def self.initalize
    @built_shell_repo = false
  end

  ##
  # Builds a "shell" repository that contains large resources that have to be
  # added to every docs build. It is *much* more efficient to build it one
  # time rather than add those resources to the build over and over again.
  def self.build!
    return if @built_shell_repo

    sh 'git init /tmp/shell'
    copy_fonts
    build_readme
    Dir.chdir '/tmp/shell' do
      sh 'git add .'
      sh 'git commit -m "add shell resources"'
    end
    @built_shell_repo = true
  end

  ##
  # Copy the fonts that take so long to add to git.
  def self.copy_fonts
    prefix = '/docs_build/resources/web/lib'
    %w[raw html].each do |dest|
      FileUtils.mkdir_p "/tmp/shell/#{dest}/static"
      %w[inter noto-sans-japanese].each do |font|
        sh "cp -r #{prefix}/#{font}/*.woff* /tmp/shell/#{dest}/static"
      end
    end
  end

  ##
  # Build the readme for the repo. This is mostly there to make the docs build's
  # sparse checkout code happy.
  def self.build_readme
    File.open('/tmp/shell/README', 'w:UTF-8') do |f|
      f.write 'Shell repository with fonts.'
    end
  end
end
