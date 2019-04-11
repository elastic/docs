# frozen_string_literal: true

require 'open3'

##
# Method to convert asciidoc files to html in example blocks like `it`
# and `before`.
module Convert
  def convert_single(from, to, asciidoctor:)
    from_dir = File.expand_path('..', from)
    init_repo from_dir unless Dir.exist?("#{from_dir}/.git")
    cmd = convert_single_cmd from, to, asciidoctor: asciidoctor
    # Use popen here instead of capture to keep stdin open to appease the
    # docker-image-always-removed paranoia in build_docs.pl
    _stdin, out, wait_thr = Open3.popen2e(*cmd)
    status = wait_thr.value
    out = out.read
    raise_status cmd, out, status unless status.success?

    out
  end

  private

  def convert_single_cmd(from, to, asciidoctor:)
    opts = %W[
      /docs_build/build_docs.pl
      --in_standard_docker
      --doc #{from}
      --out #{to}
    ]
    opts += ['--asciidoctor'] if asciidoctor
    opts
  end
end
