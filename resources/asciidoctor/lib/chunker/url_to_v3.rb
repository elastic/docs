module Chunker

  class UrlToV3

    attr_reader :header

    def initialize(doc)
      current_url = doc.attr('current-url')
      outdir = doc.attr('outdir')

      current_url ||= 'index.html'
      
      # raise ArgumentError, "Missing required attribute 'current-url'" if current_url.nil?
      raise ArgumentError, "Missing required attribute 'outdir'" if outdir.nil?

      # Hardcoded file path
      file_path = File.expand_path('v3-mapping.json', __dir__)
      # Read content from the specified file and convert it to a dictionary
      mapping = JSON.parse(File.read(file_path)) if File.exist?(file_path)


      path_dir = outdir.sub('/tmp/docsbuild/target_repo/raw', '').split('/')[0...-1].join('/')

      actual_url = '/guide' + path_dir + '/*/' + current_url

      new_url = mapping[actual_url]
      
      @header = Asciidoctor::Block.new(doc, :pass, source: <<~HTML)
      <div id="url-to-v3">
        From: <a href="#{actual_url}">CURRENT URL</a>
        To: <a href="#{new_url}">NEW URL</a>
      </div>
      HTML
    end
  end
end
