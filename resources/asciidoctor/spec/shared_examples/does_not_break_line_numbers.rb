# frozen_string_literal: true

RSpec.shared_examples "doesn't break line numbers" do
  context "doesn't break line numbers" do
    include_context 'convert'
    context 'when there is an error in the main asciidoc file' do
      let(:input) do
        <<~ASCIIDOC
          ---
          ---
          <1> callout
        ASCIIDOC
      end
      it "reports the right line for the error" do
        expect(logs).to eq('WARN: <stdin>: line 3: no callout found for <1>')
      end
    end

    context 'when there is an error in an included file' do
      let(:included) do
        'resources/does_not_break_line_numbers/missing_callout.adoc'
      end
      let(:input) { "include::#{included}[]" }
      let(:expected) { "WARN: #{included}: line 3: no callout found for <1>" }
      it "reports the rigth line for the error" do
        expect(logs).to eq(expected)
      end
    end
  end
end
