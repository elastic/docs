# frozen_string_literal: true

module Chunker
  # Add a warning to the page with a link to docs v3
  class UrlToV3
    attr_reader :url

    def initialize(doc)
      current_url = doc.attr('current-url')
      outdir = doc.attr('outdir')
      current_url ||= 'index.html'
      m = mapping
      # This only works in CI.
      segments = outdir.sub('/tmp/docsbuild/target_repo/raw', '').split('/')
      version = segments[-1] || 'unknown'
      actual_url = get_actual_url(outdir, current_url)
      new_url = if m.key?(actual_url)
                  m[actual_url]
                else
                  '/docs'
                end
      render_warning(doc, version, new_url)
    end

    def mapping
      file_path = File.expand_path('v3-mapping.json', __dir__)
      JSON.parse(File.read(file_path)) if File.exist?(file_path)
    end

    def get_path_dir(outdir)
      segments = outdir.sub('/tmp/docsbuild/target_repo/raw', '').split('/')
      if segments.empty?
        ''
      elsif segments.length > 1
        segments[0...-1].join('/')
      else
        segments[0]
      end
    end

    def get_actual_url(outdir, current_url)
      get_path_dir(outdir) + '/*/' + current_url
    end

    def render_warning(doc, version, new_url)
      if version == '8.18'
        @url = Asciidoctor::Block.new(doc, :pass, source: <<~HTML)
          <div id="url-to-v3" class="version-warning">
              A newer version is available. Check out the <a href="https://www.elastic.co#{new_url}">latest documentation</a>.
          </div>
        HTML
      else
        @url = Asciidoctor::Block.new(doc, :pass, source: <<~HTML)
          <div id="url-to-v3" class="version-warning">
              <strong>IMPORTANT</strong>: This documentation is no longer updated. Refer to <a href="https://www.elastic.co/support/eol">Elastic's version policy</a> and the <a href="https://www.elastic.co#{new_url}">latest documentation</a>.
          </div>
        HTML
      end
    end
  end
end
