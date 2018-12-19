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
    def reader.process_line line
      return line unless @process_lines

      super&.gsub!(/(added)\[([^\]]+)\]/, '\1::[\2]')
    end
    reader
  end
end