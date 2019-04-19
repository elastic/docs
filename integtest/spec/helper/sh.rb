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
  # Raise an exception based on a return status.
  def raise_status(cmd, out, status)
    outmsg = out == '' ? '' : " with stdout/stderr:\n#{out}"
    raise "#{status.stopsig} [#{cmd}] returned [#{status}]#{outmsg}"
  end
end
