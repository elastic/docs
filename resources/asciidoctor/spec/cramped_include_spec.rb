# frozen_string_literal: true

require 'cramped_include/extension'
require 'elastic_compat_preprocessor/extension'
require 'shared_examples/does_not_break_line_numbers'

RSpec.describe CrampedInclude do
  before(:each) do
    Asciidoctor::Extensions.register do
      preprocessor CrampedInclude
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_examples "doesn't break line numbers"
  include_context 'convert without logs'

  context 'when including callout lists without a blank line between them' do
    let(:input) do
      <<~ASCIIDOC
        = Test

        == Test

        include::resources/cramped_include/colist1.adoc[]
        include::resources/cramped_include/colist2.adoc[]
      ASCIIDOC
    end
    it 'renders both callout lists' do
      expect(converted).to include('<callout arearefs="CO1-1">')
      expect(converted).to include('<callout arearefs="CO2-1">')
    end
    it 'renders the sections that contain the lists' do
      expect(converted).to include('<title>P1</title>')
      expect(converted).to include('<title>P2</title>')
    end
  end

  context 'when including non-asciidoc files' do
    let(:input) do
      <<~ASCIIDOC
        ----
        include::resources/cramped_include/Example.java[]
        ----
      ASCIIDOC
    end
    it "doesn't add an extra newline" do
      expect(converted).to include('<screen>public class Example {}</screen>')
      # If it did add an extra new line it'd be here --------------^
    end
  end
end
