# frozen_string_literal: true

require 'fileutils'
require 'open3'

require_relative '../sh'

##
# Helper class for setting up source files for tests.
module Dsl
  class Source
    include Sh

    def initialize(root)
      @root = root
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
    # Write a source file and return the absolute path to that file.
    def write(dest_relative_path, text)
      realpath = path dest_relative_path
      dir = File.expand_path '..', realpath
      FileUtils.mkdir_p dir
      File.open(realpath, 'w:UTF-8') do |f|
        f.write text
      end
      realpath
    end

    ##
    # Init a git repo at a source path and make a commit that adds all of the
    # files at that path to the repo.
    def init_repo(relative_path)
      root = path relative_path
      Dir.chdir root do
        sh 'git init'
        sh 'git add .'
        sh "git commit -m 'init'"
        # Add an Elastic remote so we get a nice edit url
        sh 'git remote add elastic git@github.com:elastic/docs.git'
      end
    end

    ##
    # Transform path fragment for a source file into the path that that file
    # should have.
    def path(relative_path)
      File.expand_path(relative_path, @root)
    end
  end
end
