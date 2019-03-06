# frozen_string_literal: true

require 'pathname'
require 'edit_me/extension'

RSpec.describe EditMe do
  before(:each) do
    Asciidoctor::Extensions.register do
      tree_processor EditMe
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  spec_dir = File.dirname(__FILE__)

  it "has a nice error message if you are missing the edit url" do
    attributes = {
      'edit_urls' => '<stdin>',
    }
    warnings = <<~WARNINGS
      ERROR: invalid edit_urls, no url
      WARN: couldn't find edit url for <stdin>
    WARNINGS
    convert 'Words.', attributes, eq(warnings.strip)
  end

  it "has a nice error message if you are missing the toplevel" do
    attributes = {
      'edit_urls' => ',http://example.com',
    }
    warnings = <<~WARNINGS
      ERROR: invalid edit_urls, no toplevel
      WARN: couldn't find edit url for <stdin>
    WARNINGS
    convert 'Words.', attributes, eq(warnings.strip)
  end

  it "adds a link to the preface" do
    attributes = {
      'edit_urls' => '<stdin>,www.example.com/docs',
    }
    input = <<~ASCIIDOC
      :preface-title: Preface
      Words.
    ASCIIDOC
    expected = <<~DOCBOOK
      <preface>
      <title>Preface<ulink role="edit_me" url="www.example.com/docs">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </preface>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add a link to the preface if edit_url isn't set" do
    input = <<~ASCIIDOC
      :preface-title: Preface
      Words.
    ASCIIDOC
    expected = <<~DOCBOOK
      <preface>
      <title>Preface</title>
      <simpara>Words.</simpara>
      </preface>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "adds a link to each chapter title" do
    attributes = {
      'edit_urls' => "#{spec_dir},www.example.com/docs",
    }
    input = <<~ASCIIDOC
      include::resources/edit_me/chapter1.adoc[]

      include::resources/edit_me/chapter2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_chapter_1">
      <title>Chapter 1<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/chapter1.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </chapter>
      <chapter id="_chapter_2">
      <title>Chapter 2<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/chapter2.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </chapter>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add a link to each chapter title if edit_link is not set" do
    input = <<~ASCIIDOC
      include::resources/edit_me/chapter1.adoc[]

      include::resources/edit_me/chapter2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_chapter_1">
      <title>Chapter 1</title>
      <simpara>Words.</simpara>
      </chapter>
      <chapter id="_chapter_2">
      <title>Chapter 2</title>
      <simpara>Words.</simpara>
      </chapter>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "adds a link to each section title" do
    attributes = {
      'edit_urls' => "#{spec_dir},www.example.com/docs/",
    }
    input = <<~ASCIIDOC
      include::resources/edit_me/section1.adoc[]

      include::resources/edit_me/section2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <section id="_section_1">
      <title>Section 1<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/section1.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </section>
      <section id="_section_2">
      <title>Section 2<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/section2.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </section>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add a link to each section title if edit_link is not set" do
    input = <<~ASCIIDOC
      include::resources/edit_me/section1.adoc[]

      include::resources/edit_me/section2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <section id="_section_1">
      <title>Section 1</title>
      <simpara>Words.</simpara>
      </section>
      <section id="_section_2">
      <title>Section 2</title>
      <simpara>Words.</simpara>
      </section>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "adds a link to each appendix title" do
    attributes = {
      'edit_urls' => "#{spec_dir},www.example.com/docs",
    }
    input = <<~ASCIIDOC
      include::resources/edit_me/appendix1.adoc[]

      include::resources/edit_me/appendix2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <appendix id="_appendix_1">
      <title>Appendix 1<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/appendix1.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </appendix>
      <appendix id="_appendix_2">
      <title>Appendix 2<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/appendix2.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </appendix>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add add a link to each appendix tile if edit_url is not set" do
    input = <<~ASCIIDOC
      include::resources/edit_me/appendix1.adoc[]

      include::resources/edit_me/appendix2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <appendix id="_appendix_1">
      <title>Appendix 1</title>
      <simpara>Words.</simpara>
      </appendix>
      <appendix id="_appendix_2">
      <title>Appendix 2</title>
      <simpara>Words.</simpara>
      </appendix>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "adds a link to each glossary title" do
    attributes = {
      'edit_urls' => "#{spec_dir},www.example.com/docs",
    }
    input = <<~ASCIIDOC
      include::resources/edit_me/glossary1.adoc[]

      include::resources/edit_me/glossary2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <glossary id="_glossary_1">
      <title>Glossary 1<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/glossary1.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </glossary>
      <glossary id="_glossary_2">
      <title>Glossary 2<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/glossary2.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </glossary>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add a link to each glossary title if edit_link is not set" do
    input = <<~ASCIIDOC
      include::resources/edit_me/glossary1.adoc[]

      include::resources/edit_me/glossary2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <glossary id="_glossary_1">
      <title>Glossary 1</title>
      <simpara>Words.</simpara>
      </glossary>
      <glossary id="_glossary_2">
      <title>Glossary 2</title>
      <simpara>Words.</simpara>
      </glossary>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "adds a link to each bibliography title" do
    attributes = {
      'edit_urls' => "#{spec_dir},www.example.com/docs",
    }
    input = <<~ASCIIDOC
      include::resources/edit_me/bibliography1.adoc[]

      include::resources/edit_me/bibliography2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <bibliography id="_bibliography_1">
      <title>Bibliography 1<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/bibliography1.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </bibliography>
      <bibliography id="_bibliography_2">
      <title>Bibliography 2<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/bibliography2.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </bibliography>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add a link to each bibliography title if edit_link is not set" do
    input = <<~ASCIIDOC
      include::resources/edit_me/bibliography1.adoc[]

      include::resources/edit_me/bibliography2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <bibliography id="_bibliography_1">
      <title>Bibliography 1</title>
      <simpara>Words.</simpara>
      </bibliography>
      <bibliography id="_bibliography_2">
      <title>Bibliography 2</title>
      <simpara>Words.</simpara>
      </bibliography>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "adds a link to each dedication title" do
    attributes = {
      'edit_urls' => "#{spec_dir},www.example.com/docs",
    }
    input = <<~ASCIIDOC
      include::resources/edit_me/dedication1.adoc[]

      include::resources/edit_me/dedication2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <dedication id="_dedication_1">
      <title>Dedication 1<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/dedication1.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </dedication>
      <dedication id="_dedication_2">
      <title>Dedication 2<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/dedication2.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </dedication>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add a link to each dedication title if edit_link is not set" do
    input = <<~ASCIIDOC
      include::resources/edit_me/dedication1.adoc[]

      include::resources/edit_me/dedication2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <dedication id="_dedication_1">
      <title>Dedication 1</title>
      <simpara>Words.</simpara>
      </dedication>
      <dedication id="_dedication_2">
      <title>Dedication 2</title>
      <simpara>Words.</simpara>
      </dedication>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "adds a link to each colophon title" do
    attributes = {
      'edit_urls' => "#{spec_dir},www.example.com/docs",
    }
    input = <<~ASCIIDOC
      include::resources/edit_me/colophon1.adoc[]

      include::resources/edit_me/colophon2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <colophon id="_colophon_1">
      <title>Colophon 1<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/colophon1.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </colophon>
      <colophon id="_colophon_2">
      <title>Colophon 2<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/colophon2.adoc">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </colophon>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add a link to each colophon title if edit_link is not set" do
    input = <<~ASCIIDOC
      include::resources/edit_me/colophon1.adoc[]

      include::resources/edit_me/colophon2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <colophon id="_colophon_1">
      <title>Colophon 1</title>
      <simpara>Words.</simpara>
      </colophon>
      <colophon id="_colophon_2">
      <title>Colophon 2</title>
      <simpara>Words.</simpara>
      </colophon>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "adds a link to each floating title" do
    edit_urls = <<~CSV
      <stdin>,www.example.com/stdin
      #{spec_dir},www.example.com/docs
    CSV
    attributes = {
      'edit_urls' => edit_urls,
    }
    input = <<~ASCIIDOC
      == Chapter

      include::resources/edit_me/float1.adoc[]

      include::resources/edit_me/float2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_chapter">
      <title>Chapter<ulink role="edit_me" url="www.example.com/stdin">Edit me</ulink></title>
      <bridgehead id="_float_1" renderas="sect2">Float 1<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/float1.adoc">Edit me</ulink></bridgehead>
      <simpara>Words.</simpara>
      <bridgehead id="_float_2" renderas="sect2">Float 2<ulink role="edit_me" url="www.example.com/docs/resources/edit_me/float2.adoc">Edit me</ulink></bridgehead>
      <simpara>Words.</simpara>
      </chapter>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end

  it "does not add a link to each floating title if edit_link is not set" do
    input = <<~ASCIIDOC
      == Chapter

      include::resources/edit_me/float1.adoc[]

      include::resources/edit_me/float2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_chapter">
      <title>Chapter</title>
      <bridgehead id="_float_1" renderas="sect2">Float 1</bridgehead>
      <simpara>Words.</simpara>
      <bridgehead id="_float_2" renderas="sect2">Float 2</bridgehead>
      <simpara>Words.</simpara>
      </chapter>
    DOCBOOK
    expect(convert input).to eq(expected.strip)
  end

  it "can handle multiple edit urls" do
    edit_urls = <<~CSV
      #{spec_dir}/resources/edit_me/chapter1.adoc,www.example.com/1
      #{spec_dir}/resources/edit_me/chapter2.adoc,www.example.com/2
    CSV
    attributes = {
      'edit_urls' => edit_urls,
    }
    input = <<~ASCIIDOC
      include::resources/edit_me/chapter1.adoc[]

      include::resources/edit_me/chapter2.adoc[]
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_chapter_1">
      <title>Chapter 1<ulink role="edit_me" url="www.example.com/1">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </chapter>
      <chapter id="_chapter_2">
      <title>Chapter 2<ulink role="edit_me" url="www.example.com/2">Edit me</ulink></title>
      <simpara>Words.</simpara>
      </chapter>
    DOCBOOK
    expect(convert input, attributes).to eq(expected.strip)
  end
end
