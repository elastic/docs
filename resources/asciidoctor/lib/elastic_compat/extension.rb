require 'asciidoctor/extensions'

include Asciidoctor

# Preprocessor to turn Elastic's "wild west" formatted block extensions into
# standard asciidoctor formatted extensions
#
# Turns
#   added[6.0.0-beta1]
#
# Into
#   added::[6.0.0-beta1]
#
class ElasticCompatPreprocessor < Extensions::Preprocessor
  def process document, reader
    # while reader.has_more_lines?
    #   puts "#{reader.cursor}: #{reader.read_line}"
    # end
    lines = reader.read_lines
    for line in lines do
      line.gsub!(/(added)\[([^\]]+)\]/, '\1::[\2]')
    end
    reader.unshift_lines lines
    reader
  end
end