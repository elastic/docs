require 'asciidoctor'

include Asciidoctor

##
# Enables inline callouts which asciidoc supports but asciidoctor doesn't.
# Filed as enhancement request at
# https://github.com/asciidoctor/asciidoctor/issues/3037
#
# Usage
#
#   POST <1> /_search/scroll <2>
#
# NOTE: This isn't an asciidoctor extension so much as a hack. Just including
# the file causes us to hack asciidoctor to enable the behavior. By default we
# don't do anything if you don't set the the `inline-callouts` attribute so
# you need to *ask* for the change in behavior.
#
module InlineCallout
  InlineCalloutScanRx = /\\?<!?(|--)(\d+|\.)\1>/
  InlineCalloutSourceRx = %r(((?://|#|--|;;) ?)?(\\)?&lt;!?(|--)(\d+|\.)\3&gt;)
  InlineCalloutSourceRxt = "(\\\\)?&lt;()(\\d+|\\.)&gt;"
  InlineCalloutSourceRxMap = ::Hash.new {|h, k| h[k] = /(#{::Regexp.escape k} ?)?#{InlineCalloutSourceRxt}/ }

  # Disable VERBOSE so we don't log any warnings. It really isn't great to
  # have to patch these in like this but it gets the job done and we're looking
  # to get this into Asciidoctor proper. These methods are basically the same
  # as the methods in asciidoctor but with new regexes.
  old_verbose = $VERBOSE
  $VERBOSE = false
  Parser.class_eval do
    def self.catalog_callouts(text, document)
      found = false
      autonum = 0
      callout_rx = (document.attr? 'inline-callouts') ? InlineCalloutScanRx : CalloutScanRx
      text.scan(callout_rx) {
        # lead with assignments for Ruby 1.8.7 compat
        captured, num = $&, $2
        document.callouts.register num == '.' ? (autonum += 1).to_s : num unless captured.start_with? '\\'
        # we have to mark as found even if it's escaped so it can be unescaped
        found = true
      } if text.include? '<'
      found
    end
  end

  Substitutors.module_eval do
    def sub_callouts(text)
      autonum = 0
      text.gsub(callout_rx) {
        # honor the escape
        if $2
          # use sub since it might be behind a line comment
          $&.sub(RS, '')
        else
          Inline.new(self, :callout, $4 == '.' ? (autonum += 1).to_s : $4, :id => @document.callouts.read_next_id, :attributes => { 'guard' => $1 }).convert
        end
      }
    end

    def callout_rx
      if attr? 'line-comment'
        ((attr? 'inline-callouts') ? InlineCalloutSourceRxMap : CalloutSourceRxMap)[attr 'line-comment']
      else
        (attr? 'inline-callouts') ? InlineCalloutSourceRx : CalloutSourceRx
      end
    end
  end
  $VERBOSE = old_verbose
end
