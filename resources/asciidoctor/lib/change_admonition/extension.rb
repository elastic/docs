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
class ChangeAdmonition < Asciidoctor::Extensions::Group
  def activate(registry)
    [
        [:added, 'added', 'note'],
        [:coming, 'changed', 'note'],
        [:deprecated, 'deleted', 'warning'],
    ].each do |(name, revisionflag, tag)|
      registry.block_macro ChangeAdmonitionBlock.new(revisionflag, tag), name
      registry.inline_macro ChangeAdmonitionInline.new(revisionflag), name
    end
  end

  ##
  # Block change admonition.
  class ChangeAdmonitionBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :version, :passtext

    def initialize(revisionflag, tag)
      super(nil)
      @revisionflag = revisionflag
      @tag = tag
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      # We can *almost* go through the standard :admonition conversion but
      # that won't render the revisionflag or the revision. So we have to
      # go with this funny compound pass thing.
      admon = Asciidoctor::Block.new(parent, :pass, content_model: :compound)
      admon << Asciidoctor::Block.new(admon, :pass,
        attributes: { 'revisionflag' => @revisionflag },
        source: "<#{@tag} " \
                "revisionflag=\"#{@revisionflag}\" " \
                "revision=\"#{version}\">")
      admon << Asciidoctor::Block.new(admon, :paragraph,
        source: attrs[:passtext],
        subs: Asciidoctor::Substitutors::NORMAL_SUBS)
      admon << Asciidoctor::Block.new(admon, :pass, source: "</#{@tag}>")
    end
  end

  ##
  # Inline change admonition.
  class ChangeAdmonitionInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl
    name_positional_attributes :version, :text
    with_format :short

    def initialize(revisionflag)
      super(nil)
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
