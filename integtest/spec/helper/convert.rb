# frozen_string_literal: true

require 'open3'

##
# Method to convert asciidoc files to html in example blocks like `it`
# and `before`.
module Convert
  def convert_single(from, to)
    cmd = convert_single_cmd from, to
    # Use popen here instead of capture to keep stdin open to appease the
    # docker-image-always-removed paranoia in build_docs.pl
    _stdin, out, wait_thr = Open3.popen2e(*cmd)
    status = wait_thr.value
    out = out.read
    raise_status cmd, out, status unless status.success?

    out
  end

  def convert_all(conf, to)
    cmd = convert_all_cmd conf, to
    run_convert cmd
  end

  private

  def run_convert(cmd)
    # Use popen here instead of capture to keep stdin open to appease the
    # docker-image-always-removed paranoia in build_docs.pl
    _stdin, out, wait_thr = Open3.popen2e(*cmd)
    status = wait_thr.value
    out = out.read
    raise_status cmd, out, status unless status.success?

    out
  end

  def convert_single_cmd(from, to)
    %W[
      /docs_build/build_docs.pl
      --in_standard_docker
      --doc #{from}
      --out #{to}
    ]
  end

  def convert_all_cmd(conf, to)
    %W[
      /docs_build/build_docs.pl
      --in_standard_docker
      --all
      --push
      --target_repo #{to}
      --conf #{conf}
    ]
  end
end
