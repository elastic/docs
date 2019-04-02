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

  INCLUDE_FILE = 'resources/elastic_include_tagged/Example.java'
  def include_input(tag)
    <<~ASCIIDOC
      == Example
      [source,java]
      ----
      include::elastic-include-tagged:#{INCLUDE_FILE}[#{tag}]
      ----
    ASCIIDOC
  end

  def expected_include(include_body)
    asciidoc = <<~ASCIIDOC
      <chapter id="_example">
      <title>Example</title>
      <programlisting language="java" linenumbering="unnumbered">#{include_body.strip}</programlisting>
      </chapter>
    ASCIIDOC
    asciidoc.strip
  end

  context 'when including a tag' do
    include_context 'convert'
    let(:input) { include_input 't1' }
    let(:expected) do
      expected_include <<~JAVA
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
    include_context 'convert'
    let(:input) { include_input 't2' }
    let(:expected) do
      expected_include 'System.err.println("I\'m another example");'
    end
    it 'that part of the document if included' do
      expect(converted).to eq(expected)
    end
  end
  context 'when including an empty tag' do
    include_context 'convert'
    let(:input) { include_input 'empty' }
    it 'includes nothing' do
      expect(converted).to eq(expected_include '')
    end
  end
  context "when including a tag that doesn't have a space in it in the file" do
    include_context 'convert'
    let(:input) { include_input 'no_leading_space' }
    let(:expected) do
      expected_include 'System.err.println("no leading space");'
    end
    it 'includes the contents of the tag even though it is ugly' do
      expect(converted).to eq(expected)
    end
  end
  context 'when including a tag that contains empty lines' do
    include_context 'convert'
    let(:input) { include_input 'empty_line' }
    let(:expected) do
      expected_include <<~JAVA
        System.err.println(\"empty list after this one\");

        System.err.println("and before this one");
      JAVA
    end
    it 'includes the empty lines' do
      expect(converted).to eq(expected)
    end
  end
  context "when including a file that doesn't exist" do
    include_context 'convert'
    let(:file) { 'resources/elastic_include_tagged/DoesNotExist.java' }
    let(:input) do
      "include::elastic-include-tagged:#{file}[doesn't-matter]"
    end
    it 'the conversion contains a warning about unresolved directives' do
      expect(converted).to include(
        "Unresolved directive in &lt;stdin&gt; - include::#{file}"
      )
    end
    it 'logs a warning about the missing file' do
      expect(logs).to eq(
        "ERROR: <stdin>: line 2: include file not found: #{__dir__}/#{file}"
      )
    end
  end
  context "when including a tag that doesn't have a start tag" do
    include_context 'convert'
    let(:input) { include_input 'missing_start' }
    it "doesn't include anything" do
      expect(converted).to eq(expected_include '')
    end
    it 'logs a warning about the missing tag' do
      expect(logs).to eq(
        'WARN: <stdin>: line 5: elastic-include-tagged missing ' \
        'start tag [missing_start]'
      )
    end
  end
  context "when including a tag that doesn't have a end tag" do
    include_context 'convert'
    let(:input) { include_input 'missing_end' }
    let(:expected) do
      expected_include <<~JAVA
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
        "WARN: #{INCLUDE_FILE}: line 30: elastic-include-tagged missing " \
        'end tag [missing_end]'
      )
    end
  end
  context 'when it is written without the ::' do
    include_context 'convert'
    let(:input) do
      <<~ASCIIDOC
        == Example
        ["source","java",subs="attributes,callouts,macros"]
        ----
        include-tagged::resources/elastic_include_tagged/Example.java[t1]
        ----
      ASCIIDOC
    end
    it 'is not invoked' do
      expect(converted).to include(
        'include-tagged::resources/elastic_include_tagged/Example.java[t1]'
      )
    end
  end
  context 'when called without any parameters' do
    include_context 'convert'
    let(:input) { include_input '' }
    it 'logs a warning about the missing tag' do
      expect(logs).to eq(
        'WARN: <stdin>: line 5: elastic-include-tagged expects only a tag ' \
        'but got: {}'
      )
    end
    it 'includes nothing' do
      expect(converted).to eq(expected_include '')
    end
  end
  context 'when called more than one parameter' do
    include_context 'convert'
    let(:input) { include_input 'tag,otherparam' }
    it 'logs a warning about the missing tag' do
      expect(logs).to eq(
        'WARN: <stdin>: line 5: elastic-include-tagged expects only a tag ' \
        'but got: {1=>"tag", 2=>"otherparam"}'
      )
    end
    it 'includes nothing' do
      expect(converted).to eq(expected_include '')
    end
  end
end
