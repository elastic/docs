module Chunker

  class UrlToV3

    attr_reader :url

    def initialize(doc)
      current_url = doc.attr('current-url')
      outdir = doc.attr('outdir')
      current_url ||= 'index.html'
      file_path = File.expand_path('v3-mapping.json', __dir__)
      mapping = JSON.parse(File.read(file_path)) if File.exist?(file_path)
      segments = outdir.sub('/tmp/docsbuild/target_repo/raw', '').split('/') # This only works in CI. 
      version = segments[-1] || 'unknown'

      path_dir = if segments.empty?
        ''
      elsif segments.length > 1
        segments[0...-1].join('/')
      else
        segments[0]
      end

      actual_url = path_dir + '/*/' + current_url
      new_url = if mapping.key?(actual_url)
        mapping[actual_url]
      else
        '/docs'
      end

      if version == '8.18'
        @url = Asciidoctor::Block.new(doc, :pass, source: <<~HTML)
          <div id="url-to-v3" style="version-warning">
            A newer version is available. For the latest information, see the <a href="https://www.elastic.co#{new_url}">current release documentation</a>
          </div>
        HTML
      else
        @url = Asciidoctor::Block.new(doc, :pass, source: <<~HTML)
          <div id="url-to-v3" class="version-warning">
            <bold>IMPORTANT</bold>: No additional bug fixes or documentation updates will be released for this version. For the latest information, see the <a href="https://www.elastic.co#{new_url}">current release documentation</a>
          </div>
        HTML
      end
    end
  end
end
