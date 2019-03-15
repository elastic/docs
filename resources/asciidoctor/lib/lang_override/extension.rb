# frozen_string_literal: true

##
# Block macro that exists entirely to mark language overrides in a clean way
# without adding additional lines to the input file which would throw off
# line numbers.
#
class LangOverride < Asciidoctor::Extensions::BlockMacroProcessor
  use_dsl
  named :lang_override
  name_positional_attributes :override
  def process(parent, _target, attrs)
    Asciidoctor::Block.new(parent, :pass, :source => "// #{attrs[:override]}")
  end
end
