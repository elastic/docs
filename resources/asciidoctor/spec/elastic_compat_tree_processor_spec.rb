# frozen_string_literal: true

require 'elastic_compat_tree_processor/extension'
require 'lang_override/extension'

RSpec.describe ElasticCompatTreeProcessor do
  before(:each) do
    Asciidoctor::Extensions.register do
      treeprocessor ElasticCompatTreeProcessor
      block_macro LangOverride
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_context 'convert without logs'

  context 'when there are listings with `specialcharacters`' do
    let(:input) do
      <<~ASCIIDOC
        ["source","java",subs="attributes,callouts,macros"]
        --------------------------------------------------
        List<CategoryDefinition> categories = response.categories();
        --------------------------------------------------
      ASCIIDOC
    end
    it 'processes specialcharacters anyway' do
      expect(converted).to include('List&lt;CategoryDefinition&gt; categories')
    end
  end

  context 'when there is a definition list without a definition' do
    let(:input) do
      <<~ASCIIDOC
        `thing1`::

          def1

        `thing2`::
      ASCIIDOC
    end
    it 'successfully converts the text anyway' do
      expect(converted).to include('<term><literal>thing2</literal></term>')
    end
  end

  shared_examples 'snippet language' do |override, lang|
    name = override ? " the #{override} lang override" : 'out a lang override'
    context "for a snippet with#{name}" do
      let(:snippet) do
        snippet = <<~ASCIIDOC
          [source,js]
          ----
          GET / <1>
          ----
        ASCIIDOC
        snippet += "lang_override::[#{override}]" if override
        snippet
      end
      let(:has_lang) do
        /<programlisting language="#{lang}" linenumbering="unnumbered">/
      end
      shared_examples 'has the expected language' do
        it "has the #{lang} language" do
          expect(converted).to match(has_lang)
        end
      end
      context 'when it is alone' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            #{snippet}
          ASCIIDOC
        end
        include_examples 'has the expected language'
      end
      context 'when it is followed by a paragraph' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            #{snippet}

            Words words words.
          ASCIIDOC
        end
        include_examples 'has the expected language'
        it 'the paragraph is intact' do
          expect(converted).to match(%r{<simpara>Words words words.</simpara>})
        end
      end
      context 'when it is inside a definition list' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            Term::
            Definition
            +
            --
            #{snippet}
            --
          ASCIIDOC
        end
        include_examples 'has the expected language'
      end
      context 'when it is followed by a callout list' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            #{snippet}
            <1> foo
          ASCIIDOC
        end
        include_examples 'has the expected language'
        it 'has a working callout list' do
          expect(converted).to match(/<callout arearefs="CO1-1">\n<para>foo/)
        end
      end
    end
  end
  include_examples 'snippet language', 'CONSOLE', 'console'
  include_examples 'snippet language', 'AUTOSENSE', 'sense'
  include_examples 'snippet language', 'KIBANA', 'kibana'
  include_examples 'snippet language', 'SENSE:path/to/snippet.sense', 'sense'
  include_examples 'snippet language', nil, 'js'
end
