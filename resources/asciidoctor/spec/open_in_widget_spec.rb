# frozen_string_literal: true

require 'open_in_widget/extension'

RSpec.describe OpenInWidget do
  before(:each) do
    Asciidoctor::Extensions.register do
      treeprocessor OpenInWidget
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  spec_dir = File.dirname(__FILE__)

  def stub_file_opts(result)
    return {
      'copy_snippet' => proc { |uri, source| result << [uri, source] },
      'write_snippet' => proc { |uri, snippet| result << [uri, snippet] },
    }
  end

  %w[console sense kibana].each do |lang|
    it "supports automatic snippet extraction with #{lang} language" do
      input = <<~ASCIIDOC
        == Example
        [source,#{lang}]
        ----
        GET /
        ----
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <programlisting language="#{lang}" linenumbering="unnumbered"><ulink type="snippet" url="snippets/1.#{lang}"/>GET /</programlisting>
        </chapter>
      DOCBOOK
      file_opts = []
      actual = convert input, stub_file_opts(file_opts), eq(
        "INFO: <stdin>: line 3: writing snippet snippets/1.#{lang}"
      )
      expect(actual).to eq(expected.strip)
      expect(file_opts).to eq([
        ["snippets/1.#{lang}", "GET /\n"],
      ])
    end

    it "supports automatic snippet extraction for many snippets with #{lang} language" do
      input = <<~ASCIIDOC
        == Example
        [source,#{lang}]
        ----
        GET /
        ----

        [source,#{lang}]
        ----
        GET /
        ----

        [source,#{lang}]
        ----
        GET /
        ----

        [source,#{lang}]
        ----
        GET /
        ----
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <programlisting language="#{lang}" linenumbering="unnumbered"><ulink type="snippet" url="snippets/1.#{lang}"/>GET /</programlisting>
        <programlisting language="#{lang}" linenumbering="unnumbered"><ulink type="snippet" url="snippets/2.#{lang}"/>GET /</programlisting>
        <programlisting language="#{lang}" linenumbering="unnumbered"><ulink type="snippet" url="snippets/3.#{lang}"/>GET /</programlisting>
        <programlisting language="#{lang}" linenumbering="unnumbered"><ulink type="snippet" url="snippets/4.#{lang}"/>GET /</programlisting>
        </chapter>
      DOCBOOK
      file_opts = []
      warnings = <<~WARNINGS
        INFO: <stdin>: line 3: writing snippet snippets/1.#{lang}
        INFO: <stdin>: line 8: writing snippet snippets/2.#{lang}
        INFO: <stdin>: line 13: writing snippet snippets/3.#{lang}
        INFO: <stdin>: line 18: writing snippet snippets/4.#{lang}
      WARNINGS
      actual = convert input, stub_file_opts(file_opts), eq(warnings.strip)
      expect(actual).to eq(expected.strip)
      expect(file_opts).to eq([
        ["snippets/1.#{lang}", "GET /\n"],
        ["snippets/2.#{lang}", "GET /\n"],
        ["snippets/3.#{lang}", "GET /\n"],
        ["snippets/4.#{lang}", "GET /\n"],
      ])
    end

    it "supports override snippet path with #{lang} language" do
      input = <<~ASCIIDOC
        == Example
        [source,#{lang},snippet=snippet.#{lang}]
        ----
        GET /
        ----
      ASCIIDOC
      expected = <<~DOCBOOK
        <chapter id="_example">
        <title>Example</title>
        <programlisting language="#{lang}" linenumbering="unnumbered"><ulink type="snippet" url="snippets/snippet.#{lang}"/>GET /</programlisting>
        </chapter>
      DOCBOOK
      warnings = <<~WARNINGS
        WARN: <stdin>: line 3: reading snippets from a path makes the book harder to read
        INFO: <stdin>: line 3: copying snippet #{spec_dir}/snippets/snippet.#{lang}
      WARNINGS
      file_opts = []
      actual = convert input, stub_file_opts(file_opts), eq(warnings.strip)
      expect(actual).to eq(expected.strip)
      expect(file_opts).to eq([
        ["snippets/snippet.#{lang}", "#{spec_dir}/snippets/snippet.#{lang}"],
      ])
    end
  end

  it "strips callouts from written snippets" do
    input = <<~ASCIIDOC
      == Example
      [source,console]
      ----
      GET / <1>

      POST /foo/_doc/1
      {
        "f1": "v1" <2>
      }
      ----
    ASCIIDOC
    expected = <<~DOCBOOK
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="console" linenumbering="unnumbered"><ulink type="snippet" url="snippets/1.console"/>GET / <co id="CO1-1"/>

      POST /foo/_doc/1
      {
        "f1": "v1" <co id="CO1-2"/>
      }</programlisting>
      </chapter>
    DOCBOOK
    file_opts = []
    actual = convert input, stub_file_opts(file_opts), eq(
      "INFO: <stdin>: line 3: writing snippet snippets/1.console"
    )
    expect(actual).to eq(expected.strip)
    expected_snippet_body = <<~SNIPPET
      GET /

      POST /foo/_doc/1
      {
        "f1": "v1"
      }
    SNIPPET
    expect(file_opts).to eq([
      ["snippets/1.console", expected_snippet_body],
    ])
  end
end
