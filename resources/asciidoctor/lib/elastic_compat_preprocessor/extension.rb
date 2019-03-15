# frozen_string_literal: true

require 'asciidoctor/extensions'

##
# Preprocessor to turn Elastic's "wild west" formatted block extensions into
# standard asciidoctor formatted extensions
#
# Turns
#   added[6.0.0-beta1]
#   coming[6.0.0-beta1]
#   deprecated[6.0.0-beta1]
# Into
#   added::[6.0.0-beta1]
#   coming::[6.0.0-beta1]
#   deprecated::[6.0.0-beta1]
# Because `::` is required by asciidoctor to invoke block macros but isn't
# required by asciidoc.
#
# Turns
#   words words added[6.0.0-beta1]
#   words words changed[6.0.0-beta1]
#   words words deprecated[6.0.0-beta1]
# Into
#   words words added:[6.0.0-beta1]
#   words words changed:[6.0.0-beta1]
#   words words deprecated:[6.0.0-beta1]
# Because `:` is required by asciidoctor to invoke inline macros but isn't
# required by asciidoc.
#
# Turns
#   include-tagged::foo[tag]
# Into
#   include::elastic-include-tagged:foo[tag]
# To chain into the ElasticIncludeTagged processor which is *slightly* different
# than asciidoctor's built in tagging support.
#
# Turns
#   --
#   :api: bulk
#   :request: BulkRequest
#   :response: BulkResponse
#   --
# Into
#   :api: bulk
#   :request: BulkRequest
#   :response: BulkResponse
# Because asciidoctor clears attributes set in a block. See
# https://github.com/asciidoctor/asciidoctor/issues/2993
#
# Turns
#   ["source","sh",subs="attributes"]
#   --------------------------------------------
#   wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-{version}.zip
#   wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-{version}.zip.sha512
#   shasum -a 512 -c elasticsearch-{version}.zip.sha512 <1>
#   unzip elasticsearch-{version}.zip
#   cd elasticsearch-{version}/ <2>
#   --------------------------------------------
#   <1> Compares the SHA of the downloaded `.zip` archive and the published checksum, which should output
#       `elasticsearch-{version}.zip: OK`.
#   <2> This directory is known as `$ES_HOME`.
#
# Into
#   ["source","sh",subs="attributes,callouts"]
#   --------------------------------------------
#   wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-{version}.zip
#   wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-{version}.zip.sha512
#   shasum -a 512 -c elasticsearch-{version}.zip.sha512 <1>
#   unzip elasticsearch-{version}.zip
#   cd elasticsearch-{version}/ <2>
#   --------------------------------------------
#   <1> Compares the SHA of the downloaded `.zip` archive and the published checksum, which should output
#       `elasticsearch-{version}.zip: OK`.
#   <2> This directory is known as `$ES_HOME`.
# Because asciidoc adds callouts to all "source" blocks. We'd *prefer* to do
# this in the tree processor because it is less messy but we can't because
# asciidoctor checks the `:callout` sub before giving us a chance to add it.
#
# Turns
#   ----
#   foo
#   ------
#
# Into
#   ----
#   foo
#   ----
# Because Asciidoc permits these mismatches but asciidoctor does not. We'll
# emit a warning because, permitted or not, they are bad style.
#
# With the help of ElasticCompatTreeProcessor turns
#   [source,js]
#   ----
#   foo
#   ----
#   // CONSOLE
#
# Into
#   [source,console]
#   ----
#   foo
#   ----
# Because Elastic has thousands of these constructs but Asciidoctor feels
# strongly that comments should not convey meaning. This is a totally
# reasonable stance and we should migrate away from these comments in new
# docs when it is possible. But for now we have to support the comments as
# well.
#
class ElasticCompatPreprocessor < Asciidoctor::Extensions::Preprocessor
  include Asciidoctor::Logging

  INCLUDE_TAGGED_DIRECTIVE_RX = /^include-tagged::([^\[][^\[]*)\[(#{Asciidoctor::CC_ANY}+)?\]$/
  SOURCE_WITH_SUBS_RX = /^\["source", ?"[^"]+", ?subs="(#{Asciidoctor::CC_ANY}+)"\]$/
  CODE_BLOCK_RX = /^-----*$/
  SNIPPET_RX = %r{//\s*(?:AUTOSENSE|KIBANA|CONSOLE|SENSE:[^\n<]+)}
  LEGACY_MACROS = 'added|beta|coming|deprecated|experimental'
  LEGACY_BLOCK_MACRO_RX = /^(#{LEGACY_MACROS})\[([^\]]*)\]/
  LEGACY_INLINE_MACRO_RX = /(#{LEGACY_MACROS})\[([^\]]*)\]/

  def process(_document, reader)
    reader.instance_variable_set :@in_attribute_only_block, false
    reader.instance_variable_set :@code_block_start, nil
    def reader.process_line(line)
      return line unless @process_lines

      if @in_attribute_only_block
        return line unless line == '--'

        @in_attribute_only_block = false
        line.clear
      elsif INCLUDE_TAGGED_DIRECTIVE_RX =~ line
        return nil if preprocess_include_directive "elastic-include-tagged:#{$1}", $2

        # the line was not a valid include line and we've logged a warning
        # about it so we should do the asciidoctor standard thing and keep
        # it intact. This is how we do that.
        @look_ahead += 1
        line
      elsif line == '--'
        lines = self.lines
        lines.shift
        while Asciidoctor::AttributeEntryRx =~ (check_line = lines.shift)
        end
        return line unless check_line == '--'

        @in_attribute_only_block = true
        line.clear
      else
        line = super
        return nil if line.nil?

        if SOURCE_WITH_SUBS_RX =~ line
          line.sub! "subs=\"#{$1}\"", "subs=\"#{$1},callouts\"" unless $1.include? 'callouts'
        end
        if CODE_BLOCK_RX =~ line
          if @code_block_start
            if line != @code_block_start
              line.replace(@code_block_start)
              logger.warn message_with_context "MIGRATION: code block end doesn't match start", :source_location => cursor
            end
            @code_block_start = nil
          else
            @code_block_start = line
          end
        end

        # First convert the "block" version of these macros. We convert them
        # to block macros because they are at the start of the line....
        line&.gsub!(LEGACY_BLOCK_MACRO_RX, '\1::[\2]')
        # Then convert the "inline" version of these macros. We convert them
        # to inline macros because they are *not* at the start of the line....
        line&.gsub!(LEGACY_INLINE_MACRO_RX, '\1:[\2]')

        # Transform Elastic's traditional comment based marking for
        # AUTOSENSE/KIBANA/CONSOLE snippets into a marker that we can pick
        # up during tree processing to turn the snippet into a marked up
        # CONSOLE snippet. Asciidoctor really doesn't recommend this sort of
        # thing but we have thousands of them and it'll take us some time to
        # stop doing it.
        line&.gsub!(SNIPPET_RX, 'pass:[\0]')
      end
    end
    reader
  end
end
