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

  ##
  # Like the 'convert with logs' shared context, but also captures any files
  # that would be copied by the conversion process to the `copied` array. That
  # array contains tuples of the form
  # [image_path_from_asciidoc_file, image_path_on_disk] and is in the order
  # that the images source be copied.
  shared_context 'convert intercepting copies' do
    include_context 'convert with logs'

    # [] is the initial value but it is mutated by the conversion
    let(:copied_storage) { [] }
    let(:convert_attributes) do
      stub_file_opts(copied_storage).tap do |attrs|
        attrs['resources'] = resources if defined?(resources)
        attrs['copy-callout-images'] = copy_callout_images \
          if defined?(copy_callout_images)
      end
    end
    let(:copied) do
      # Force evaluation of converted because it populates copied_storage
      converted
      copied_storage
    end
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

    # TODO: finish converting this to standard rspec
    context "when the document contains an override snippet in #{lang}" do
      include_context 'convert intercepting copies'
      let(:input) do
        <<~ASCIIDOC
          == Example
          [source,#{lang},snippet=snippet.#{lang}]
          ----
          GET /
          ----
        ASCIIDOC
      end
      it 'includes a link to the overridden path' do
        expect(converted).to include(
          %(<ulink type="snippet" url="snippets/snippet.#{lang}"/>)
        )
      end
      it 'logs that it copies the snippet' do
        expect(logs).to include(
          "INFO: <stdin>: line 3: copying snippet #{spec_dir}/snippets/snippet.#{lang}"
        )
      end
      it 'logs a warning about how bad of an idea this is' do
        expect(logs).to include(
          "WARN: <stdin>: line 3: MIGRATION: reading snippets from a path makes the book harder to read"
        )
      end
      it 'copies the file' do
        expect(copied).to eq([
          ["snippets/snippet.#{lang}", "#{spec_dir}/snippets/snippet.#{lang}"],
        ])
      end
      context 'when you disable the migration warning' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            :migration-warning-override-snippet: false
            [source,#{lang},snippet=snippet.#{lang}]
            ----
            GET /
            ----
          ASCIIDOC
        end
        it 'does not log a warning about how bad an idea this is' do
          expect(logs).not_to include(
            "MIGRATION: reading snippets from a path makes the book harder to read"
          )
        end
      end
    end

    it "logs an error if override snippet is missing with #{lang} language" do
      input = <<~ASCIIDOC
        == Example
        [source,#{lang},snippet=missing.#{lang}]
        ----
        GET /
        ----
      ASCIIDOC
      warnings = <<~WARNINGS
        ERROR: <stdin>: line 3: can't read snippet from #{spec_dir}/snippets/missing.#{lang}
      WARNINGS
      file_opts = []
      convert input, stub_file_opts(file_opts), eq(warnings.strip)
      expect(file_opts).to eq([])
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
