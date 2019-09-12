# frozen_string_literal: true

require 'fileutils'

require_relative 'sh'

##
# Helper class for setting up source files for tests.
class Repo
  include Sh

  attr_reader :name, :root

  ##
  # Set to false to prevent adding an Elastic clone when the repo
  # is initialized
  attr_accessor :add_elastic_remote

  def initialize(name, root)
    @name = name
    @root = root
    @add_elastic_remote = true
    @initialized = false
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
  # Read a file in the repo to a string.
  def read(source_relative_path)
    realpath = path source_relative_path
    File.open realpath, 'r:UTF-8', &:read
  end

  def delete(source_relative_path)
    realpath = path source_relative_path
    File.delete realpath
  end

  ##
  # Copy a file into the source path, returning the destination path.
  def cp(source_file, dest_relative_path)
    realpath = path dest_relative_path
    dir = File.expand_path '..', realpath
    FileUtils.mkdir_p dir
    FileUtils.cp source_file, realpath
  end

  ##
  # Transform path fragment for a source file into the path that that file
  # should have.
  def path(source_relative_path)
    File.expand_path(source_relative_path, @root)
  end

  ##
  # Commit all changes to the repo.
  def commit(message)
    Dir.chdir @root do
      init_repo!
      sh 'git add .'
      sh "git commit -m '#{message}'"
    end
  end

  ##
  # Creates a new branch from the current branch and checks it out.
  def switch_to_new_branch(new_branch)
    Dir.chdir @root do
      sh "git checkout -b #{new_branch}"
    end
  end

  ##
  # Checks out a branch.
  def switch_to_branch(branch)
    Dir.chdir @root do
      sh "git checkout #{branch}"
    end
  end

  ##
  # The hash of the last commit.
  def short_hash
    Dir.chdir @root do
      hash = sh 'git rev-parse --short HEAD'
      hash.strip
    end
  end

  ##
  # Create a worktree at `dest` for the branch `branch`.
  def create_worktree(dest, branch)
    Dir.chdir @root do
      sh "git worktree add #{dest} #{branch}"
    end
  end

  ##
  # Clone this repo from some directory on disk
  def clone_from(src)
    @initialized = true
    sh "git clone #{src} #{@root}"
  end

  ##
  # Push commits in this repo to some remote, maybe a directory on disk.
  def push_to(dest)
    Dir.chdir @root do
      sh "git push #{dest}"
    end
  end

  private

  def init_repo!
    return if @initialized

    sh 'git init'
    if @add_elastic_remote
      # Add an Elastic remote so we get a nice edit url
      sh 'git remote add elastic git@github.com:elastic/docs.git'
    end
    @initialized = true
  end
end
