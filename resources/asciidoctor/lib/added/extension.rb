require 'asciidoctor/extensions'

include Asciidoctor

# Extension for marking when something was added.
#
# Usage
#
#   added::[6.0.0-beta1]
#
class Added < Extensions::BlockMacroProcessor
  use_dsl
  named :added
  name_positional_attributes 'version', 'passtext'

  puts "registering Added"

  def process parent, reader, attrs
    puts %(processing Added   #{reader.lines})
    docbook = %(<note revisionflag="added" revision="#{attrs['version']}">
        <simpara>#{attrs['passtext']}</simpara>
    </note>)
    
    create_pass_block parent, docbook, {}, subs: nil
  end
end
