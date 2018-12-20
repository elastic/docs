require 'asciidoctor/extensions'

include Asciidoctor

# Extension for marking when something was added.
#
# Usage
#
#   added::[6.0.0-beta1]
#
class AddedBlock < Extensions::BlockMacroProcessor
  use_dsl
  named :added
  name_positional_attributes :version, :passtext

  def process parent, target, attrs
    docbook = <<~DOCBOOK
    <note revisionflag="added" revision="#{attrs[:version]}">
      <simpara>#{attrs[:passtext]}</simpara>
    </note>
    DOCBOOK
    
    create_pass_block parent, docbook, {}, subs: nil
  end
end
