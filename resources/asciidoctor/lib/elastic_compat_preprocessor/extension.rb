require 'asciidoctor/extensions'

include Asciidoctor

# Preprocessor to turn Elastic's "wild west" formatted block extensions into
# standard asciidoctor formatted extensions
#
# Turns
#   added[6.0.0-beta1]
#   include-tagged::foo[tag]
#
# Into
#   added::[6.0.0-beta1]
#   include::elastic-include-tagged:foo[tag]
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
          # the line was not a valid include line and we've logged a warning
          # about it so we should do the asciidoctor standard thing and keep
          # it intact. This is how we do that.
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
