# frozen_string_literal: true

require 'care_admonition/extension'
require 'change_admonition/extension'
require 'elastic_compat_preprocessor/extension'
require 'elastic_compat_tree_processor/extension'
require 'elastic_include_tagged/extension'
require 'lang_override/extension'
require 'open_in_widget/extension'
require 'shared_examples/does_not_break_line_numbers'

RSpec.describe ElasticCompatPreprocessor do
  before(:each) do
    Asciidoctor::Extensions.register CareAdmonition
    Asciidoctor::Extensions.register ChangeAdmonition
    Asciidoctor::Extensions.register OpenInWidget
    Asciidoctor::Extensions.register do
      block_macro LangOverride
      preprocessor ElasticCompatPreprocessor
      include_processor ElasticIncludeTagged
      treeprocessor ElasticCompatTreeProcessor
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  spec_dir = File.dirname(__FILE__)

  include_examples "doesn't break line numbers"

  context 'admonitions' do
    shared_examples 'admonition' do
      include_context 'convert without logs'

      shared_examples 'invokes the block macro' do
        it 'invokes the block macro' do
          expect(converted).to include <<~DOCBOOK.strip
            <#{tag_start}>
            <simpara>
          DOCBOOK
        end
      end
      context 'when the admonition is alone on a line' do
        let(:input) { invocation }
        include_examples 'invokes the block macro'
      end
      context 'when the admonition has spaces before it' do
        let(:input) { "   #{invocation}" }
        include_examples 'invokes the block macro'
      end
      context 'when the admonition has spaces after it' do
        let(:input) { "#{invocation}   " }
        include_examples 'invokes the block macro'
      end
      context 'when the admonition has a `]` in it' do
        let(:invocation_text) { 'link:link.html[Title]' }
        let(:input) { invocation_with_text }
        let(:expected) do
          <<~DOCBOOK
            <#{tag_start}>
            <simpara><ulink url="link.html">Title</ulink></simpara>
            </#{tag_end}>
          DOCBOOK
        end
        it 'invokes the block macro' do
          expect(converted).to include(expected)
        end
      end

      shared_examples 'invokes the inline macro' do
        it 'invokes the inline macro' do
          expect(converted).to include("<phrase #{phrase}/>")
        end
      end
      context 'when the admonition is surrounded by other text' do
        let(:input) { "words #{invocation} words" }
        include_examples 'invokes the inline macro'
      end
      context 'when the admonition has text before it' do
        let(:input) { "words #{invocation}" }
        include_examples 'invokes the inline macro'
      end
      context 'when the admonition has text after it' do
        let(:input) { "#{invocation} words" }
        include_examples 'invokes the inline macro'
      end

      context 'when the admonition is skipped' do
        let(:input) do
          <<~ASCIIDOC
            words before skip
            ifeval::["true" == "false"]
            #{invocation}
            endif::[]
            words after skip
          ASCIIDOC
        end
        it 'skips the admonition' do
          expect(converted).not_to include('revisionflag')
        end
        it 'properly converts the rest of the text' do
          expect(converted).to include('words before skip')
          expect(converted).to include('words after skip')
        end
      end
    end

    shared_examples 'change admonition' do
      include_examples 'admonition'
      let(:invocation) { "#{name}[some_version]" }
      let(:invocation_with_text) { "#{name}[some_version, #{invocation_text}]" }
      let(:tag_start) do
        %(#{tag} revisionflag="#{revisionflag}" revision="some_version")
      end
      let(:tag_end) { tag }
      let(:phrase) { %(revisionflag="#{revisionflag}" revision="some_version") }
    end
    context 'for added' do
      include_context 'change admonition'
      let(:name) { 'added' }
      let(:revisionflag) { 'added' }
      let(:tag) { 'note' }
    end
    context 'for coming' do
      include_context 'change admonition'
      let(:name) { 'coming' }
      let(:revisionflag) { 'changed' }
      let(:tag) { 'note' }
    end
    context 'for added' do
      include_context 'change admonition'
      let(:name) { 'deprecated' }
      let(:revisionflag) { 'deleted' }
      let(:tag) { 'warning' }
    end

    shared_examples 'care admonition' do
      include_examples 'admonition'
      let(:invocation) { "#{name}[]" }
      let(:invocation_with_text) { "#{name}[#{invocation_text}]" }
      let(:tag_start) { %(warning role="#{name}") }
      let(:tag_end) { 'warning' }
      let(:phrase) { %(role="#{name}") }
    end
    context 'for beta' do
      include_context 'care admonition'
      let(:name) { 'beta' }
    end
    context 'for experimental' do
      include_context 'care admonition'
      let(:name) { 'experimental' }
    end
  end

  context 'when the document contains include-tagged::' do
    # include-tagged:: was a macro we built for AsciiDoc for tagged includes
    # from files. It doesn't have exactly the same form as the include directive
    # that we use with asciidoctor so the processor morphs it.
    include_context 'convert without logs'
    let(:input) do
      <<~ASCIIDOC
        [source,java]
        ----
        include-tagged::resources/elastic_include_tagged/Example.java[t1]
        ----
      ASCIIDOC
    end
    it 'it includes the tagged portion of the file' do
      expect(converted).to include(<<~JAVA.strip)
        System.err.println("I'm an example");
        for (int i = 0; i &lt; 10; i++) {
            System.err.println(i); <co id="CO1-1"/>
        }
      JAVA
    end
  end

  context 'when the document a block containing only attributes' do
    include_context 'convert without logs'
    let(:input) do
      <<~ASCIIDOC
        :inheader: foo

        = Test

        --
        :outheader: bar
        --

        [id="{inheader}-{outheader}"]
        == Header

        <<{inheader}-{outheader}>>
      ASCIIDOC
    end
    it 'uses the attributes for the header' do
      expect(converted).to include('<chapter id="foo-bar">')
    end
    it 'uses the attributes outside of the header' do
      expect(converted).to include('<xref linkend="foo-bar"/>')
    end
    context 'when it is followed by other complex processing' do
      let(:input) do
        <<~ASCIIDOC
          :inheader: foo

          = Test

          --
          :outheader: bar
          --

          == Header
          added[some_version]
        ASCIIDOC
      end
      it 'the processing works as expected' do
        expect(converted).to include(<<~ASCIIDOC.strip)
          <note revisionflag="added" revision="some_version">
        ASCIIDOC
      end
    end
  end

  context 'when a block contains no attributes' do
    include_context 'convert without logs'
    let(:input) do
      <<~ASCIIDOC
        == Header

        --
        added[some_version]
        --

      ASCIIDOC
    end
    it 'the contents of the block are processed normally' do
      expect(converted).to include(<<~ASCIIDOC.strip)
        <note revisionflag="added" revision="some_version">
      ASCIIDOC
    end
  end

  context 'when a block contains some attributes and other things' do
    include_context 'convert without logs'
    let(:input) do
      <<~ASCIIDOC
        --
        :attr: test
        added::[some_version]
        --

        {attr}
      ASCIIDOC
    end
    it "doesn't remove the block" do
      # The point here is that the attribute setting *doesn't* apply to the
      # text because we haven't doctored the block.
      expect(converted).to include('<simpara>{attr}</simpara>')
    end
  end

  context "when a source block doesn't have callouts" do
    include_context 'convert without logs'
    let(:input) do
      <<~ASCIIDOC
        == Example
        ["source","sh",subs="attributes"]
        --------------------------------------------
        cd elasticsearch-{version}/ <1>
        --------------------------------------------
        <1> This directory is known as `$ES_HOME`.
      ASCIIDOC
    end
    it 'processes callouts anyway' do
      expect(converted).to include(<<~ASCIIDOC.strip)
        cd elasticsearch-{version}/ <co id="CO1-1"/>
      ASCIIDOC
    end
    context 'when the block is skipped' do
      let(:input) do
        <<~ASCIIDOC
          == Example

          ifeval::["true" == "false"]
          ["source","sh",subs="attributes"]
          --------------------------------------------
          cd elasticsearch-{version}/ <1>
          --------------------------------------------
          <1> This directory is known as `$ES_HOME`.
          endif::[]
        ASCIIDOC
      end
      it 'skips the block' do
        expect(converted).to eq(<<~DOCBOOK.strip)
          <chapter id="_example">
          <title>Example</title>

          </chapter>
        DOCBOOK
      end
    end
  end

  context 'when there is a code block with a mismatched start and end' do
    include_context 'convert with logs'
    let(:input) do
      <<~ASCIIDOC
        ----
        foo
        --------
      ASCIIDOC
    end
    it 'renders the code block' do
      expect(converted).to include('<screen>foo</screen>')
    end
    it 'logs a migration warning' do
      expect(logs).to eq(<<~LOGS.strip)
        WARN: <stdin>: line 3: MIGRATION: code block end doesn't match start
      LOGS
    end
    context 'when the block is skipped' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          ifeval::["true" == "false"]
          ----
          foo
          --------
          endif::[]
        ASCIIDOC
      end
      it 'skips the block' do
        expect(converted).to eq(<<~DOCBOOK.strip)
          <chapter id="_example">
          <title>Example</title>

          </chapter>
        DOCBOOK
      end
      it "doesn't log anything" do
        expect(logs).to eq('')
      end
    end
  end

  context 'when a code block contains table-style outputs' do
    include_context 'convert with logs'
    let(:table) do
      <<~TEXT.strip
            author     |     name      |  page_count   | release_date
        ---------------+---------------+---------------+------------------------
        Dan Simmons    |Hyperion       |482            |1989-05-26T00:00:00.000Z
        Frank Herbert  |Dune           |604            |1965-06-01T00:00:00.000Z
      TEXT
    end
    let(:input) do
      <<~ASCIIDOC
        --------------------------------------------------
        #{table}
        --------------------------------------------------
      ASCIIDOC
    end
    it 'preservers the table' do
      expect(converted).to include("<screen>#{table}</screen>")
    end
  end

  shared_context 'general snippet' do |lang, override|
    include_context 'convert with logs'
    let(:convert_attributes) do
      {
        'copy_snippet' => proc { |uri, source| },
        'write_snippet' => proc { |uri, source| },
      }
    end
    let(:snippet) do
      snippet = <<~ASCIIDOC
        [source,js]
        ----
        GET / <1>
        ----
      ASCIIDOC
      snippet += override if override
      snippet
    end
    let(:has_lang) do
      /<programlisting language="#{lang}" linenumbering="unnumbered">/
    end
    let(:input) do
      <<~ASCIIDOC
        == Example
        #{snippet}
      ASCIIDOC
    end
  end
  shared_examples 'linked snippet' do |override, lang, path|
    let(:has_link_to_path) { %r{<ulink type="snippet" url="#{path}"/>} }
    shared_examples 'converted with override' do
      it "has the #{lang} language" do
        expect(converted).to match(has_lang)
      end
      it 'have a link to the snippet' do
        expect(converted).to match(has_link_to_path)
      end
    end

    context 'when there is a space after //' do
      include_context 'general snippet', lang, "// #{override}"
      include_examples 'converted with override'
    end
    context 'when there is not a space after //' do
      include_context 'general snippet', lang, "//#{override}"
      include_examples 'converted with override'
    end
    context 'when there is a space after the override command' do
      include_context 'general snippet', lang, "// #{override} "
      include_examples 'converted with override'
    end
  end
  shared_examples 'extracted linked snippet' do |override, lang|
    context "for a snippet with the #{override} lang override" do
      let(:expected_warnings) do
        "INFO: <stdin>: line 3: writing snippet snippets/1.#{lang}"
      end
      include_examples 'linked snippet', override, lang, "snippets/1.#{lang}"
    end
  end
  include_examples 'extracted linked snippet', 'CONSOLE', 'console'
  include_examples 'extracted linked snippet', 'AUTOSENSE', 'sense'
  include_examples 'extracted linked snippet', 'KIBANA', 'kibana'
  context 'for a snippet with the SENSE override pointing to a specific path' do
    let(:expected_warnings) do
      <<~WARNINGS
        INFO: <stdin>: line 3: copying snippet #{spec_dir}/snippets/snippet.sense
        WARN: <stdin>: line 3: MIGRATION: reading snippets from a path makes the book harder to read
      WARNINGS
    end
    include_examples(
      'linked snippet',
      'SENSE: snippet.sense',
      'sense',
      'snippets/snippet.sense'
    )
  end
  context 'for a snippet without an override' do
    include_context 'general snippet', 'js', nil
    let(:has_any_link) { /<ulink type="snippet"/ }

    it 'has the js language' do
      expect(converted).to match(has_lang)
    end
    it 'not have a link to any snippet' do
      expect(converted).not_to match(has_any_link)
    end
  end

  context 'when a file is included with leveloffset' do
    include_context 'convert without logs'
    let(:input) do
      <<~ASCIIDOC
        = Foo
        include::resources/elastic_compat_preprocessor/target.adoc[leveloffset=+1]
      ASCIIDOC
    end
    it 'has the right offset' do
      expect(converted).to include('<chapter id="_target">')
    end
  end
end
