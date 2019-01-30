require 'inline_callout/extension'

RSpec.describe InlineCallout do
  it "enables support for inline callouts if requested" do
    attributes = {
      'inline-callouts' => '',
    }
    input = <<~ASCIIDOC
      ----
      POST <1> /_search/scroll <2>
      ----
      <1> words
      <2> other words
    ASCIIDOC
    expected = <<~DOCBOOK
      <preface>
      <title></title>
      <screen>POST <co id="CO1-1"/> /_search/scroll <co id="CO1-2"/></screen>
      <calloutlist>
      <callout arearefs="CO1-1">
      <para>words</para>
      </callout>
      <callout arearefs="CO1-2">
      <para>other words</para>
      </callout>
      </calloutlist>
      </preface>
    DOCBOOK
    expect(convert(input, attributes)).to eq(expected.strip)
  end

  it "does not enable support for inline callouts by default" do
    input = <<~ASCIIDOC
      ----
      POST <1> /_search/scroll <2>
      ----
      <1> words
      <2> other words
    ASCIIDOC
    expected = <<~DOCBOOK
      <preface>
      <title></title>
      <screen>POST &lt;1&gt; /_search/scroll <co id="CO1-1"/></screen>
      <calloutlist>
      <callout arearefs="">
      <para>words</para>
      </callout>
      <callout arearefs="CO1-1">
      <para>other words</para>
      </callout>
      </calloutlist>
      </preface>
    DOCBOOK
    actual = convert input, {}, eq('WARN: <stdin>: line 4: no callout found for <1>')
    expect(actual).to eq(expected.strip)
  end
end