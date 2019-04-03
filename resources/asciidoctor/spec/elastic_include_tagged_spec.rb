# frozen_string_literal: true

require 'elastic_include_tagged/extension'

RSpec.describe ElasticIncludeTagged do
  before(:each) do
    Asciidoctor::Extensions.register do
      include_processor ElasticIncludeTagged
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  let(:include_file) { 'resources/elastic_include_tagged/Example.java' }
  let(:input) do
    <<~ASCIIDOC
      == Example
      [source,java]
      ----
      include::elastic-include-tagged:#{include_file}[#{tag}]
      ----
    ASCIIDOC
  end
  include_context 'convert'
  let(:expected) do
    asciidoc = <<~ASCIIDOC
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="java" linenumbering="unnumbered">#{expected_include.strip}</programlisting>
      </chapter>
    ASCIIDOC
    asciidoc.strip
  end

  context 'when including a tag' do
    let(:tag) { 't1' }
    let(:expected_include) do
      <<~JAVA
        System.err.println("I'm an example");
        for (int i = 0; i &lt; 10; i++) {
            System.err.println(i); <co id="CO1-1"/>
        }
      JAVA
    end
    it 'that part of the document if included' do
      expect(converted).to eq(expected)
    end
  end
  context 'when including a different tag' do
    let(:tag) { 't2' }
    let(:expected_include) { 'System.err.println("I\'m another example");' }
    it 'that part of the document if included' do
      expect(converted).to eq(expected)
    end
  end
  context 'when including an empty tag' do
    let(:tag) { 'empty' }
    let(:expected_include) { '' }
    it 'includes nothing' do
      expect(converted).to eq(expected)
    end
  end
  context "when including a tag that doesn't have a space in it in the file" do
    let(:tag) { 'no_leading_space' }
    let(:expected_include) { 'System.err.println("no leading space");' }
    it 'includes the contents of the tag even though it is ugly' do
      expect(converted).to eq(expected)
    end
  end
  context 'when including a tag that contains empty lines' do
    let(:tag) { 'empty_line' }
    let(:expected_include) do
      <<~JAVA
        System.err.println(\"empty list after this one\");

        System.err.println("and before this one");
      JAVA
    end
    it 'includes the empty lines' do
      expect(converted).to eq(expected)
    end
  end
  context "when including a file that doesn't exist" do
    let(:include_file) { 'resources/elastic_include_tagged/DoesNotExist.java' }
    let(:tag)          { "doesn't-matter"                                     }
    let(:expected_log) do
      absolute_path = "#{__dir__}/#{include_file}"
      "ERROR: <stdin>: line 5: include file not found: #{absolute_path}"
    end
    it 'the conversion contains a warning about unresolved directives' do
      expect(converted).to include(
        "Unresolved directive in &lt;stdin&gt; - include::#{include_file}"
      )
    end
    it 'logs a warning about the missing file' do
      expect(logs).to include(expected_log)
    end
  end
  context "when including a tag that doesn't have a start tag" do
    let(:tag)              { 'missing_start' }
    let(:expected_include) { ''              }
    it "doesn't include anything" do
      expect(converted).to eq(expected)
    end
    it 'logs a warning about the missing tag' do
      expect(logs).to eq(
        'WARN: <stdin>: line 5: elastic-include-tagged missing ' \
        'start tag [missing_start]'
      )
    end
  end
  context "when including a tag that doesn't have a end tag" do
    let(:tag) { 'missing_end' }
    let(:expected_include) do
      <<~JAVA
        System.err.println("this tag doesn't have any end");
            }
        }
      JAVA
    end
    it 'includes the rest of the file' do
      expect(converted).to eq(expected)
    end
    it 'logs a warning about the missing tag' do
      expect(logs).to eq(
        "WARN: #{include_file}: line 30: elastic-include-tagged missing " \
        'end tag [missing_end]'
      )
    end
  end
  context 'when it is written in AsciiDoc form' do
    let(:input) do
      <<~ASCIIDOC
        == Example
        ["source","java",subs="attributes,callouts,macros"]
        ----
        include-tagged::#{include_file}[t1]
        ----
      ASCIIDOC
    end
    it 'is not invoked' do
      expect(converted).to include(
        "include-tagged::#{include_file}[t1]"
      )
    end
  end
  context 'when called without any parameters' do
    let(:tag)              { '' }
    let(:expected_include) { '' }
    it 'logs a warning about the missing tag' do
      expect(logs).to eq(
        'WARN: <stdin>: line 5: elastic-include-tagged expects only a tag ' \
        'but got: {}'
      )
    end
    it 'includes nothing' do
      expect(converted).to eq(expected)
    end
  end
  context 'when called more than one parameter' do
    let(:tag)              { 'tag,otherparam' }
    let(:expected_include) { ''               }
    it 'logs a warning about the missing tag' do
      expect(logs).to eq(
        'WARN: <stdin>: line 5: elastic-include-tagged expects only a tag ' \
        'but got: {1=>"tag", 2=>"otherparam"}'
      )
    end
    it 'includes nothing' do
      expect(converted).to eq(expected)
    end
  end
end
