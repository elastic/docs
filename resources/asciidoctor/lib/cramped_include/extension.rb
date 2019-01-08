require 'asciidoctor/extensions'

include Asciidoctor

# Preprocessor to support more "cramped" include statements. Usually something
# like
#   include::resources/1.adoc[]
#   include::resources/2.adoc[]
# will result in syntax errors if 1.adoc ends in only a single new line. Things
# like callout lists require that they be followed by an empty line or else
# the thing below them will get sucked into the callout list. This isn't a
# problem with asciidoc, and to be better compatible with it try and work around
# this problem by adding an extra new line after every sequence of lines we
# include. In theory this *shouldn't* bother us because we don't include things
# that are sensitive to the extra line.
class CrampedInclude < Extensions::Preprocessor
  def process document, reader
    def reader.prepare_lines data, opts = {}
      super.unshift ''
    end
    reader
  end
end
