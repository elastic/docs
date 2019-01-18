require 'asciidoctor/extensions'

include Asciidoctor

class Added < Extensions::Group
  def activate registry
    registry.block_macro AddedBlock
    registry.inline_macro AddedInline
  end
end

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

# Extension for marking when something was added.
#
# Usage
#
#   Foo added:[6.0.0-beta1]
#
class AddedInline < Extensions::InlineMacroProcessor
  use_dsl
  named :added
  name_positional_attributes :version, :text
  with_format :short

  def process parent, target, attrs
    if attrs[:text]
      <<~DOCBOOK
        <phrase revisionflag="added" revision="#{attrs[:version]}">
          #{attrs[:text]}
        </phrase>
      DOCBOOK
    else
      <<~DOCBOOK
        <phrase revisionflag="added" revision="#{attrs[:version]}"/>
      DOCBOOK
    end
  end
end
