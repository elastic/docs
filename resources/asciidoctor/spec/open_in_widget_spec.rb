# frozen_string_literal: true

require 'open_in_widget/extension'

RSpec.describe OpenInWidget do
  before(:each) do
    Asciidoctor::Extensions.register OpenInWidget
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  let(:spec_dir) { File.dirname(__FILE__) }
  let(:backend) { :html5 }

  def stub_file_opts(result)
    {
      'copy_snippet' => proc { |uri, source| result << [uri, source] },
      'write_snippet' => proc { |uri, snippet| result << [uri, snippet] },
    }
  end

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

  shared_context 'open in widget' do
    let(:relative_path) { "snippets/#{index}.#{lang}" }
    ##
    # In most examples below the exact text of the snippet is written as the
    # snippet. *But* in some examples we write something slightly different.
    let(:copied_snippet) { "#{text}\n" }
    ##
    # In most examples below we write the snippet so this is the log we expect.
    # But one we override it.
    let(:expected_log) do
      <<~LOG.strip
        INFO: <stdin>: line #{line}: writing snippet #{relative_path}
      LOG
    end

    shared_context 'basic snippet' do
      it 'preserves the snippet' do
        expect(converted).to include(text)
      end
      let(:expected_link) do
        <<~HTML
          <div class="#{lang}_widget" data-snippet="#{relative_path}"></div>
        HTML
      end
      it 'adds a link to extracted snippet' do
        expect(converted).to include(expected_link)
      end
      it 'logs that it wrote the snippet' do
        expect(logs).to include(expected_log)
      end
      it 'writes the snippet' do
        expect(copied).to include([relative_path, copied_snippet])
      end
    end
    context 'when there is a code block with this language' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          [source,#{lang}]
          ----
          GET /
          ----
        ASCIIDOC
      end
      include_context 'basic snippet'
      let(:text) { 'GET /' }
      let(:index) { 1 }
      let(:line) { 3 }
      context 'which contains a callout' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            [source,#{lang}]
            ----
            GET / <1>
            ----
            <1> words
          ASCIIDOC
        end
        include_context 'basic snippet'
        let(:text) do
          'GET / <b class="conum">(1)</b>'
        end
        let(:copied_snippet) { "GET /\n" }
        let(:index) { 1 }
        let(:line) { 3 }
        it 'writes the snippet without the callout' do
          expect(copied).to include(["snippets/1.#{lang}", "GET /\n"])
        end
      end
      context 'with a role' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            [source,#{lang},role=foo]
            ----
            GET / <1>
            ----
            <1> words
          ASCIIDOC
        end
        let(:expected_link) do
          <<~HTML
            <div class="#{lang}_widget foo" data-snippet="#{relative_path}"></div>
          HTML
        end
        it 'adds a link to extracted snippet' do
          expect(converted).to include(expected_link)
        end
        let(:text) { 'GET /' }
        let(:copied_snippet) { "GET /\n" }
        let(:index) { 1 }
        let(:line) { 3 }
        it 'writes the snippet without the callout' do
          expect(copied).to include(["snippets/1.#{lang}", "GET /\n"])
        end
      end
    end
    context 'when there are many blocks with the language' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          [source,#{lang}]
          ----
          GET /foo
          ----

          [source,#{lang}]
          ----
          GET /bar
          ----

          [source,#{lang}]
          ----
          GET /baz
          ----

          [source,#{lang}]
          ----
          GET /bort
          ----
        ASCIIDOC
      end
      context 'first snippet' do
        include_context 'basic snippet'
        let(:text) { 'GET /foo' }
        let(:index) { 1 }
        let(:line) { 3 }
      end
      context 'second snippet' do
        include_context 'basic snippet'
        let(:text) { 'GET /bar' }
        let(:index) { 2 }
        let(:line) { 8 }
      end
      context 'third snippet' do
        include_context 'basic snippet'
        let(:text) { 'GET /baz' }
        let(:index) { 3 }
        let(:line) { 13 }
      end
      context 'fourth snippet' do
        include_context 'basic snippet'
        let(:text) { 'GET /bort' }
        let(:index) { 4 }
        let(:line) { 18 }
      end
    end
    context 'when there is an override snippet' do
      let(:relative_path) { "snippets/snippet.#{lang}" }
      let(:absolue_path) { "#{spec_dir}/#{relative_path}" }
      let(:input) do
        <<~ASCIIDOC
          == Example
          [source,#{lang},snippet=snippet.#{lang}]
          ----
          GET /
          ----
        ASCIIDOC
      end
      let(:line) { 1 }
      let(:text) { 'GET /' }
      include_context 'basic snippet'
      let(:expected_log) do
        <<~LOG
          INFO: <stdin>: line 3: copying snippet #{absolue_path}
        LOG
      end
      # Instead of writing some snippet text like the default for this attribute
      # we are copying a file. When we copy files we log their paths in place
      # of the text so we assert that the log of copies contains the path.
      let(:copied_snippet) { absolue_path }
      it 'logs a warning about how bad of an idea this is' do
        expect(logs).to include(<<~LOG.strip)
          WARN: <stdin>: line 3: MIGRATION: reading snippets from a path makes the book harder to read
        LOG
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
        it "doesn't log a warning about how bad an idea this is" do
          expect(logs).not_to include(<<~LOG.strip)
            MIGRATION: reading snippets from a path makes the book harder to read
          LOG
        end
      end
      context 'when the override snippet is missing' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            [source,#{lang},snippet=missing.#{lang}]
            ----
            GET /
            ----
          ASCIIDOC
        end
        it 'logs an error' do
          expect(logs).to eq(<<~LOG.strip)
            ERROR: <stdin>: line 3: can't read snippet from #{spec_dir}/snippets/missing.#{lang}
          LOG
        end
        it "doesn't copy anything" do
          expect(copied).to eq([])
        end
      end
    end
  end
  context 'for the console widget' do
    include_context 'open in widget'
    let(:lang) { 'console' }
  end
  context 'for the sense widget' do
    include_context 'open in widget'
    let(:lang) { 'sense' }
  end
  context 'for the kibana widget' do
    include_context 'open in widget'
    let(:lang) { 'kibana' }
  end
  context 'for the ess widget' do
    include_context 'open in widget'
    let(:lang) { 'ess' }
  end
  context 'for the ece widget' do
    include_context 'open in widget'
    let(:lang) { 'ece' }
  end
end
