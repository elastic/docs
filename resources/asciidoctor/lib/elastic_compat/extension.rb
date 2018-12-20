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
  IncludeTaggedDirectiveRx = /^include-tagged::([^\[][^\[]*)\[(#{CC_ANY}+)?\]$/

  def process document, reader
    def reader.process_line line
      return line unless @process_lines

      if IncludeTaggedDirectiveRx =~ line then
        if preprocess_include_directive "elastic-include-tagged:#{$1}", $2 then
          nil
        else
          # the line was not a valid include line and is unchanged
          # mark it as visited and return it
          @look_ahead += 1
          line
        end
      else
        line = super
        line&.gsub!(/(added)\[([^\]]*)\]/, '\1::[\2]')  
      end
    end
    reader
  end
end