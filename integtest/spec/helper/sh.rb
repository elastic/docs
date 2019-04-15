# frozen_string_literal: true

require 'open3'

##
# Defines methods to run commands in example blocks like `it` and `before`.
module Sh
  ##
  # Execute a command and return the result. Use this to execute commands in
  # `before` sections to prepare the environment to test.
  def sh(cmd)
    out, status = Open3.capture2e cmd
    raise_status cmd, out, status unless status.success?

    out
  end

  ##
  # Init a git repo in root and commit any files in it.
  def init_repo(root)
    Dir.chdir root do
      sh 'git init'
      sh 'git add .'
      sh "git commit -m 'init'"
      # Add an Elastic remote so we get a nice edit url
      sh 'git remote add elastic git@github.com:elastic/docs.git'
    end
  end

  ##
  # Raise an exception based on a return status.
  def raise_status(cmd, out, status)
    outmsg = out == '' ? '' : " with stdout/stderr:\n#{out}"
    raise "#{status.stopsig} [#{cmd}] returned [#{status}]#{outmsg}"
  end
end
