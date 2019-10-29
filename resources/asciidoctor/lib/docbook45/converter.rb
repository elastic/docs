# encoding: UTF-8

require 'asciidoctor'
require 'asciidoctor/converter/docbook5'

module Docbook45
  ##
  # This is a copy of Asciidoctor 1.5.8's docbook 4.5 converter. It is required
  # to support docbook 4.5 in Asciidoctor 2 because the Asciidoctor 2 dropped
  # support for docbook 4.5
  class Converter < Asciidoctor::Converter::DocBook5Converter
    register_for 'docbook45'

    def convert_document node
      if (root_tag_name = node.doctype) == 'manpage'
        root_tag_name = 'refentry'
      end
      result = ['<?xml version="1.0" encoding="UTF-8"?>']
      result << <<~XML
        <!DOCTYPE #{root_tag_name} PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd">
      XML
      result << ((node.attr? 'toclevels') ? %(<?asciidoc-toc maxdepth="#{node.attr 'toclevels'}"?>) : '<?asciidoc-toc?>') if node.attr? 'toc'
      result << ((node.attr? 'sectnumlevels') ? %(<?asciidoc-numbered maxdepth="#{node.attr 'sectnumlevels'}"?>) : '<?asciidoc-numbered?>') if node.attr? 'sectnums'
      lang_attribute = (node.attr? 'nolang') ? '' : %( lang="#{node.attr 'lang', 'en'}")
      result << %(<#{root_tag_name}#{lang_attribute}#{common_attributes node.id}>)
      result << (document_info_tag node) unless node.noheader
      unless (docinfo_content = node.docinfo :header).empty?
        result << docinfo_content
      end
      result << node.content if node.blocks?
      unless (docinfo_content = node.docinfo :footer).empty?
        result << docinfo_content
      end
      result << %(</#{root_tag_name}>)
      result.join Asciidoctor::LF
    end

    def convert_admonition node
      # address a bug in the DocBook 4.5 DTD
      if node.parent.context == :example
        %(<para>
#{super}
</para>)
      else
        super
      end
    end

    def convert_olist node
      result = []
      num_attribute = node.style ? %( numeration="#{node.style}") : ''
      start_attribute = (node.attr? 'start') ? %( override="#{node.attr 'start'}") : ''
      result << %(<orderedlist#{common_attributes node.id, node.role, node.reftext}#{num_attribute}>)
      result << %(<title>#{node.title}</title>) if node.title?
      node.items.each_with_index do |item, idx|
        result << (idx == 0 ? %(<listitem#{start_attribute}>) : '<listitem>')
        result << %(<simpara>#{item.text}</simpara>)
        result << item.content if item.blocks?
        result << '</listitem>'
      end
      result << %(</orderedlist>)
      result.join Asciidoctor::LF
    end

    def convert_inline_anchor node
      case node.type
      when :ref
        %(<anchor#{common_attributes node.id, nil, node.text}/>)
      when :xref
        if (path = node.attributes['path'])
          # QUESTION should we use refid as fallback text instead? (like the html5 backend?)
          %(<ulink url="#{node.target}">#{node.text || path}</ulink>)
        else
          linkend = node.attributes['fragment'] || node.target
          (text = node.text) ? %(<link linkend="#{linkend}">#{text}</link>) : %(<xref linkend="#{linkend}"/>)
        end
      when :link
        %(<ulink url="#{node.target}">#{node.text}</ulink>)
      when :bibref
        target = node.target
        %(<anchor#{common_attributes target, nil, "[#{target}]"}/>[#{target}])
      end
    end

    def convert_author_tag author
      result = []
      result << '<author>'
      result << %(<firstname>#{author.firstname}</firstname>) if author.firstname
      result << %(<othername>#{author.middlename}</othername>) if author.middlename
      result << %(<surname>#{author.lastname}</surname>) if author.lastname
      result << %(<email>#{author.email}</email>) if author.email
      result << '</author>'
      result.join Asciidoctor::LF
    end

    def common_attributes id, role = nil, reftext = nil
      res = id ? %( id="#{id}") : ''
      res = %(#{res} role="#{role}") if role
      res = %(#{res} xreflabel="#{reftext}") if reftext
      res
    end

    def document_info_tag doc
      info_tag_prefix = doc.doctype
      result = []
      result << %(<#{info_tag_prefix}info>)
      result << document_title_tags(doc.doctitle :partition => true, :use_fallback => true) unless doc.notitle
      if (date = (doc.attr? 'revdate') ? (doc.attr 'revdate') : ((doc.attr? 'reproducible') ? nil : (doc.attr 'docdate')))
        result << %(<date>#{date}</date>)
      end
      if doc.attr? 'copyright'
        CopyrightRx =~ (doc.attr 'copyright')
        result << '<copyright>'
        result << %(<holder>#{$1}</holder>)
        result << %(<year>#{$2}</year>) if $2
        result << '</copyright>'
      end
      if doc.has_header?
        unless (authors = doc.authors).empty?
          if authors.size > 1
            result << '<authorgroup>'
            authors.each {|author| result << (author_tag author) }
            result << '</authorgroup>'
          else
            result << author_tag(author = authors[0])
            result << %(<authorinitials>#{author.initials}</authorinitials>) if author.initials
          end
        end
        if (doc.attr? 'revdate') && ((doc.attr? 'revnumber') || (doc.attr? 'revremark'))
          result << %(<revhistory>
<revision>)
          result << %(<revnumber>#{doc.attr 'revnumber'}</revnumber>) if doc.attr? 'revnumber'
          result << %(<date>#{doc.attr 'revdate'}</date>) if doc.attr? 'revdate'
          result << %(<authorinitials>#{doc.attr 'authorinitials'}</authorinitials>) if doc.attr? 'authorinitials'
          result << %(<revremark>#{doc.attr 'revremark'}</revremark>) if doc.attr? 'revremark'
          result << %(</revision>
</revhistory>)
        end
        unless (head_docinfo = doc.docinfo).empty?
          result << head_docinfo
        end
        result << %(<orgname>#{doc.attr 'orgname'}</orgname>) if doc.attr? 'orgname'
      end
      result << %(</#{info_tag_prefix}info>)

      if doc.doctype == 'manpage'
        result << '<refmeta>'
        result << %(<refentrytitle>#{doc.attr 'mantitle'}</refentrytitle>) if doc.attr? 'mantitle'
        result << %(<manvolnum>#{doc.attr 'manvolnum'}</manvolnum>) if doc.attr? 'manvolnum'
        result << %(<refmiscinfo class="source">#{doc.attr 'mansource', '&#160;'}</refmiscinfo>)
        result << %(<refmiscinfo class="manual">#{doc.attr 'manmanual', '&#160;'}</refmiscinfo>)
        result << '</refmeta>'
        result << '<refnamediv>'
        result += (doc.attr 'mannames').map {|n| %(<refname>#{n}</refname>) } if doc.attr? 'mannames'
        result << %(<refpurpose>#{doc.attr 'manpurpose'}</refpurpose>) if doc.attr? 'manpurpose'
        result << '</refnamediv>'
      end

      result.join Asciidoctor::LF
    end

    def document_title_tags title
      if title.subtitle?
        %(<title>#{title.main}</title>
<subtitle>#{title.subtitle}</subtitle>)
      else
        %(<title>#{title}</title>)
      end
    end
  end
end
