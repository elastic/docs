# frozen_string_literal: true

require 'asciidoctor/extensions'
require_relative '../delegating_converter.rb'

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
  MACRO_CONF = [
    [:added, 'added', 'note', 'Added in', nil],
    [:coming, 'changed', 'note', 'Coming in', nil],
    [:deprecated, 'deleted', 'warning', 'Deprecated in', ' u-strikethrough'],
  ].freeze
  def activate(registry)
    MACRO_CONF.each do |(name, revisionflag, tag, message, title_class)|
      block = ChangeAdmonitionBlock.new revisionflag, tag, message
      inline = ChangeAdmonitionInline.new revisionflag, message, title_class
      registry.block_macro block, name
      registry.inline_macro inline, name
    end
    DelegatingConverter.setup(registry.document) { |doc| Converter.new doc }
  end

  ##
  # Properly renders change admonitions.
  class Converter < DelegatingConverter
    def convert_admonition(node)
      return yield if node.document.basebackend? 'html'
      return yield unless (flag = node.attr 'revisionflag')

      <<~DOCBOOK.strip
        <#{tag_name = node.attr 'name'} revisionflag="#{flag}" revision="#{node.attr 'version'}">
        <simpara>#{node.content}</simpara>
        </#{tag_name}>
      DOCBOOK
    end
  end

  ##
  # Block change admonition.
  class ChangeAdmonitionBlock < Asciidoctor::Extensions::BlockMacroProcessor
    use_dsl
    name_positional_attributes :version, :passtext

    def initialize(revisionflag, tag, message)
      super(nil)
      @revisionflag = revisionflag
      @tag = tag
      @message = message
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      passtext = attrs[:passtext]
      if parent.document.basebackend? 'html'
        process_html parent, version, passtext
      else
        process_docbook parent, version, passtext
      end
    end

    def process_html(parent, version, passtext)
      text = "#{@message} #{version}."
      source = passtext || text
      title = passtext ? text : nil
      Asciidoctor::Block.new parent, :admonition, source: source, attributes: {
        'name' => @tag,
        'revisionflag' => @revisionflag,
        'version' => version,
        'title' => title,
      }
    end

    def process_docbook(parent, version, passtext)
      Asciidoctor::Block.new(
        parent, :admonition, source: passtext, attributes: {
          'name' => @tag,
          'revisionflag' => @revisionflag,
          'version' => version,
        }
      )
    end
  end

  ##
  # Inline change admonition.
  class ChangeAdmonitionInline < Asciidoctor::Extensions::InlineMacroProcessor
    use_dsl
    name_positional_attributes :version, :text
    format :short

    def initialize(revisionflag, message, extra_title_class)
      super(nil)
      @revisionflag = revisionflag
      @message = message
      @extra_title_class = extra_title_class
    end

    def process(parent, _target, attrs)
      version = attrs[:version]
      text = attrs[:text]
      if parent.document.basebackend? 'html'
        process_html parent, version, text
      else
        process_docbook parent, version, text
      end
    end

    def process_html(parent, version, text)
      message = "#{@message} #{version}."
      message += ' ' + text if text
      Asciidoctor::Inline.new(
        parent, :admonition, message, type: 'change', attributes: {
          'title_type' => 'version',
          'title_class' => "u-mono#{@extra_title_class}",
          'title' => version,
        }
      )
    end

    def process_docbook(parent, version, text)
      Asciidoctor::Inline.new parent, :quoted, docbook_text(version, text)
    end

    def docbook_text(version, text)
      if text
        <<~DOCBOOK
          <phrase revisionflag="#{@revisionflag}" revision="#{version}">
            #{text}
          </phrase>
        DOCBOOK
      else
        <<~DOCBOOK
          <phrase revisionflag="#{@revisionflag}" revision="#{version}"/>
        DOCBOOK
      end
    end
  end
end
