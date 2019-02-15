# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Extensions for marking when something was added, when it *will* be added, or
# when it was deprecated.
#
# Usage
#
#   added::[6.0.0-beta1]
#   coming::[6.0.0-beta1]
#   deprecated::[6.0.0-beta1]
#   Foo added:[6.0.0-beta1]
#   Foo coming:[6.0.0-beta1]
#   Foo deprecated:[6.0.0-beta1]
#
class ChangeAdmonishment < Asciidoctor::Extensions::Group
  def activate(registry)
    [
        [:added, 'added'],
        [:coming, 'changed'],
        [:deprecated, 'deleted'],
    ].each do |(name, revisionflag)|
      registry.block_macro ChangeAdmonishmentBlock.new(revisionflag), name
      registry.inline_macro ChangeAdmonishmentInline.new(revisionflag), name
    end
  end

  ##
  # Block change admonishment.
  class ChangeAdmonishmentBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :version, :passtext

    def initialize(revisionflag)
      super
      @revisionflag = revisionflag
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      # We can *almost* go through the standard :admonition conversion but
      # that won't render the revisionflag or the revision. So we have to
      # go with this funny compound pass thing.
      note = Asciidoctor::Block.new(parent, :pass, :content_model => :compound)
      note << Asciidoctor::Block.new(note, :pass,
          :source => "<note revisionflag=\"#{@revisionflag}\" revision=\"#{version}\">",
          :attributes => { 'revisionflag' => @revisionflag })
      note << Asciidoctor::Block.new(note, :paragraph,
          :source => attrs[:passtext],
          :subs => Asciidoctor::Substitutors::NORMAL_SUBS)
      note << Asciidoctor::Block.new(note, :pass, :source => "</note>")
    end
  end

  ##
  # Inline change admonishment.
  class ChangeAdmonishmentInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl
    name_positional_attributes :version, :text
    with_format :short

    def initialize(revisionflag)
      super
      @revisionflag = revisionflag
    end

    def process(_parent, _target, attrs)
      if attrs[:text]
        <<~DOCBOOK
          <phrase revisionflag="#{@revisionflag}" revision="#{attrs[:version]}">
            #{attrs[:text]}
          </phrase>
        DOCBOOK
      else
        <<~DOCBOOK
          <phrase revisionflag="#{@revisionflag}" revision="#{attrs[:version]}"/>
        DOCBOOK
      end
    end
  end
end
