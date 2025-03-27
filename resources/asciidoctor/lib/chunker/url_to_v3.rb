module Chunker

  class UrlToV3

    attr_reader :header

    def initialize(doc)
      current_url = doc.attr('current-url')
      outdir = doc.attr('outdir')

      current_url ||= 'index.html'
      
      # raise ArgumentError, "Missing required attribute 'current-url'" if current_url.nil?
      # raise ArgumentError, "Missing required attribute 'outdir'" if outdir.nil?

      # Hardcoded file path
      file_path = File.expand_path('v3-mapping.json', __dir__)
      # Read content from the specified file and convert it to a dictionary
      mapping = JSON.parse(File.read(file_path)) if File.exist?(file_path)

      segments = outdir.sub('/tmp/docsbuild/target_repo/raw', '').split('/')

      path_dir = if segments.empty?
        ''
      elsif segments.length > 1
        segments[0...-1].join('/')
      else
        segments[0]
      end

      actual_url = 'https://www.elastic.co/guide' + path_dir + '/*/' + current_url

      if mapping.key?(actual_url)
        new_url = mapping[actual_url]
      else
       new_url = '/docs'
      end

      @header = Asciidoctor::Block.new(doc, :pass, source: <<~HTML)
      <div id="url-to-v3">
        From: #{actual_url}
        To: <a href="https://www.elastic.co#{new_url}">NEW URL</a>
      </div>
      HTML
    end
  end
end
